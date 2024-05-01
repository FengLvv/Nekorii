using System.Linq;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RendererUtils;
using UnityEngine.Rendering.Universal;

namespace Post_Process_Effect.Render_Feature {
	public class SSR : ScriptableRendererFeature {
		[System.Serializable]
		public class Settings {
			public LayerMask ReflectionLayer;
		}

		public Settings settings = new Settings();

		class CustomRenderPass : ScriptableRenderPass {
			Material _ssrMaterial;
			Material _blurMaterial;
			

			FilteringSettings filtering; //在之后设置
			ShaderTagId shaderTag = new ShaderTagId( "UniversalForward" ); //执行带有这个tag的shader
			static LayerMask reflectionLayer;

			RTHandle _cameraDepthBuffer;
			RTHandle _cameraColorBuffer;
			RTHandle _cameraNormalBuffer;
			RTHandle _tempTex1;
			RTHandle _tempTex2;
			RenderTextureDescriptor m_Descriptor;

			//cmd name
			string _passName = "SSR";

			//初始类的时候传入材质
			public CustomRenderPass( Settings settings ) {
				_ssrMaterial = Resources.Load<Material>( "Material/SSR" );
				_blurMaterial = Resources.Load<Material>( "Material/PPBlur" );
				// _material = CoreUtils.CreateEngineMaterial(settings.shaderNeeded);`

				RenderQueueRange queue = new RenderQueueRange(); //设置filter的队列
				queue.lowerBound = RenderQueueRange.transparent.lowerBound;
				queue.upperBound = RenderQueueRange.transparent.upperBound;
				filtering = new FilteringSettings( queue, settings.ReflectionLayer ); //设置filter
				reflectionLayer = settings.ReflectionLayer;
			}

			// execute each frame when set up camera
			// create temp rt
			public override void OnCameraSetup( CommandBuffer cmd, ref RenderingData renderingData ) {
				// get z-buffer and color buffer
				_cameraDepthBuffer = renderingData.cameraData.renderer.cameraDepthTargetHandle;
				_cameraColorBuffer = renderingData.cameraData.renderer.cameraColorTargetHandle;
			}

			// execute each frame in render event
			public override void Execute( ScriptableRenderContext context, ref RenderingData renderingData ) {
				if( _ssrMaterial is null || _blurMaterial is null ) {
					Debug.Log( "Not set material" );
					return;
				}

				if( renderingData.cameraData.camera.cameraType != CameraType.Game ) return;

				//input parameter from volume
				VolumeStack vs = VolumeManager.instance.stack;
				var parameters = vs.GetComponent<SSRParameter>();

				if( parameters.IsActive() == false ) {
					return;
				}

				CommandBuffer cmd = CommandBufferPool.Get( name:_passName );

				using( new ProfilingScope( cmd, new ProfilingSampler( cmd.name ) ) ) {

					// Down sample
					m_Descriptor = new RenderTextureDescriptor( Screen.width, Screen.height, RenderTextureFormat.Default, 0 ){
						depthBufferBits = 0
					};

					RenderingUtils.ReAllocateIfNeeded( ref _tempTex1, m_Descriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name:"_tempTex1" );
					RenderingUtils.ReAllocateIfNeeded( ref _tempTex2, m_Descriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name:"_tempTex2" );

					// store the light to quarter size texture
					Shader.SetGlobalFloat( "_MarchSteps", parameters.MarchSteps.value );
					Shader.SetGlobalFloat( "_DepthTolerance", parameters.DepthTolerance.value );
					Blitter.BlitCameraTexture( cmd, _cameraDepthBuffer, _tempTex1, _ssrMaterial, 0 );
					// Blitter.BlitCameraTexture( cmd, _cameraDepthBuffer, _tempTex1, _volumeLightMaterial, 0 );

					// Bilateral blur
					if( parameters.EnableBlur.value ) {
						// set blur parameter, normalize in shader
						float[] spacialPara = new float[5];
						spacialPara[2] = CalculateGaussian( parameters.SpacialSigma.value, 0 );
						spacialPara[3] = spacialPara[1] = CalculateGaussian( parameters.SpacialSigma.value, 1 );
						spacialPara[0] = spacialPara[4] = CalculateGaussian( parameters.SpacialSigma.value, 2 );
						Shader.SetGlobalFloatArray( "_SpatialWeight", spacialPara );
						float colorSigma = parameters.ColorSigma.value;
						Shader.SetGlobalVector( "_ColorWeightParam", new Vector2( 1 / ( colorSigma * Mathf.Sqrt( 2 * Mathf.PI ) ), -1 / ( 2 * colorSigma * colorSigma ) ) );

						Shader.SetGlobalFloat( "_BlurStepMultiple", parameters.BlurStepMultiple.value );
						Blitter.BlitCameraTexture( cmd, _tempTex1, _tempTex2, _blurMaterial, 2 );
						Blitter.BlitCameraTexture( cmd, _tempTex2, _tempTex1, _blurMaterial, 3 );
					}

					// Blit to color buffer
					// Blitter.BlitCameraTexture( cmd, _tempTex1, _cameraColorBuffer );

					cmd.SetRenderTarget( _cameraColorBuffer, _cameraDepthBuffer );
					Shader.SetGlobalTexture( "_ReflectionTex", _tempTex1 );
					RendererListDesc rendererListDesc = new RendererListDesc( shaderTag, renderingData.cullResults, renderingData.cameraData.camera ){
						overrideMaterial = _ssrMaterial,
						overrideMaterialPassIndex = 1,
						rendererConfiguration = PerObjectData.None,
						renderQueueRange = RenderQueueRange.all,
						layerMask = reflectionLayer,
					};
					var rendererList = context.CreateRendererList( rendererListDesc );
					cmd.DrawRendererList( rendererList );
					


					// Set z buffer and blit to color buffer
					// Blitter.BlitCameraTexture( cmd, _cameraDepthBuffer, _cameraColorBuffer, _volumeLightMaterial, 0 );
				}



				// var draw = CreateDrawingSettings( shaderTag, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags );
				// draw.overrideMaterial = _ssrMaterial;
				// draw.overrideMaterialPassIndex = 1; //材质覆盖

				context.ExecuteCommandBuffer( cmd );
				cmd.Clear();


				CommandBufferPool.Release( cmd );
			}

			//清除任何分配的临时RT
			public override void OnCameraCleanup( CommandBuffer cmd ) {
				//_tempTex?.Release(); //如果用的RenderingUtils.ReAllocateIfNeeded创建，就不要清除，否则会出bug（纹理传入不了材质）
			}

			float CalculateGaussian( float sigma, float distance ) {
				float space_factor1 = 1 / ( sigma * Mathf.Sqrt( 2 * Mathf.PI ) );
				float space_factor2 = Mathf.Exp( ( -distance * distance ) / ( 2 * sigma * sigma ) );
				return space_factor1 * space_factor2;
			}



		}

		/*************************************************************************/
		CustomRenderPass _ssrPass;

		// run when create render feature
		public override void Create() {
			// initialize CustomRenderPass
			_ssrPass = new CustomRenderPass( settings ){
				// render volume light before postprocess
				renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing - 10,
			};
		}

		// run when change parameter
		public override void SetupRenderPasses( ScriptableRenderer renderer, in RenderingData renderingData ) {
			if( renderingData.cameraData.cameraType == CameraType.Game ) {
				// claim the input buffer
				_ssrPass.ConfigureInput( ScriptableRenderPassInput.Color );
				_ssrPass.ConfigureInput( ScriptableRenderPassInput.Depth );
				_ssrPass.ConfigureInput( ScriptableRenderPassInput.Normal );
			}
		}

		// run with each camera, inject ScriptableRenderPass 
		public override void AddRenderPasses( ScriptableRenderer renderer, ref RenderingData renderingData ) {
			if( renderingData.cameraData.cameraType == CameraType.Game ) {
				renderer.EnqueuePass( _ssrPass );
			}
		}
	}
}