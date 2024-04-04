using System.Linq;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Post_Process_Effect.Render_Feature {
	public class VolumeLight : ScriptableRendererFeature {
		[System.Serializable]
		public class Settings {
		}

		public Settings settings = new Settings();

		class CustomRenderPass : ScriptableRenderPass {
			Material _volumeLightMaterial;
			Material _blurMaterial;
			readonly static int MieScatteringFactor = Shader.PropertyToID( "_MieScatteringFactor" );

			RTHandle _cameraDepthBuffer;
			RTHandle _cameraColorBuffer;
			RTHandle _tempTex1;
			RTHandle _tempTex2;
			RenderTextureDescriptor m_Descriptor;

			//cmd name
			string _passName = "VolumeLightPass";

			//初始类的时候传入材质
			public CustomRenderPass( Settings settings ) {
				_volumeLightMaterial = Resources.Load<Material>( "Volume Light/Volume Light Material" );
				_blurMaterial = Resources.Load<Material>( "Blur/PPBlur" );
				// _material = CoreUtils.CreateEngineMaterial(settings.shaderNeeded);`
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
				if( _volumeLightMaterial is null ) {
					Debug.Log( "Not set volume material" );
					return;
				}

				if( renderingData.cameraData.camera.cameraType != CameraType.Game ) return;

				CommandBuffer cmd = CommandBufferPool.Get( name:_passName );

				using( new ProfilingScope( cmd, new ProfilingSampler( cmd.name ) ) ) {
					// set global shader parameters
					//input parameter from volume
					VolumeStack vs = VolumeManager.instance.stack;
					var paramaters = vs.GetComponent<VolumeLightParameter>();
				
					// set parameter
					Shader.SetGlobalVector( MieScatteringFactor, CalculateHG( paramaters.HG_g.value ) );
					Shader.SetGlobalFloat( "_MarchSteps", paramaters.MarchSteps.value );
					Shader.SetGlobalFloat( "_MaxStepDistance", paramaters.MaxStepDistance.value );
					Shader.SetGlobalColor( "_LightPowerColorEnhance", paramaters.LightColor.value );
					Shader.SetGlobalFloat( "_ExtinctionFactor", paramaters.ExtinctionFactor.value );
					Shader.SetGlobalFloat( "_NearPlaneDistance", paramaters.NearPlaneDistance.value );
					Shader.SetGlobalFloat( "_FarPointDistance", paramaters.FarPointDistance.value );
					Shader.SetGlobalFloat( "_Density", paramaters.Density.value );

					// set blur parameter, normalize in shader
					float[] spacialPara = new float[5];
					spacialPara[2] = CalculateGaussian( paramaters.SpacialSigma.value, 0 );
					spacialPara[3] = spacialPara[1] = CalculateGaussian( paramaters.SpacialSigma.value, 1 );
					spacialPara[0] = spacialPara[4] = CalculateGaussian( paramaters.SpacialSigma.value, 2 );
					// Debug.Log( spacialPara[0] + " " + spacialPara[1] + " " + spacialPara[2] + " " + spacialPara[3] + " " + spacialPara[4] );

					Shader.SetGlobalFloatArray( "_SpatialWeight", spacialPara );
					float colorSigma = paramaters.ColorSigma.value;
					Shader.SetGlobalVector( "_ColorWeightParam", new Vector2( 1 / ( colorSigma * Mathf.Sqrt( 2 * Mathf.PI ) ), -1 / ( 2 * colorSigma * colorSigma ) ) );

					// Down sample
					int downSampleTimes = (int)Mathf.Pow( 2, paramaters.DownSampleTimes.value );
					m_Descriptor = new RenderTextureDescriptor( Screen.width / downSampleTimes, Screen.height / downSampleTimes, RenderTextureFormat.Default, 0 ){
						depthBufferBits = 0
					};
		
					RenderingUtils.ReAllocateIfNeeded( ref _tempTex1, m_Descriptor, FilterMode.Bilinear,
						TextureWrapMode.Clamp, name:"down4_VolumeLight" );
					RenderingUtils.ReAllocateIfNeeded( ref _tempTex2, m_Descriptor, FilterMode.Bilinear,
						TextureWrapMode.Clamp, name:"down4_VolumeLight" );

					// store the light to quarter size texture
					Blitter.BlitCameraTexture( cmd, _cameraDepthBuffer, _tempTex1, _volumeLightMaterial, 0 );

					// Bilateral blur
					if( paramaters.EnableBlur.value ) {
						Shader.SetGlobalFloat( "_BlurStepMultiple", paramaters.BlurStepMultiple.value );
						Blitter.BlitCameraTexture( cmd, _tempTex1, _tempTex2, _blurMaterial, 2 );
						Blitter.BlitCameraTexture( cmd, _tempTex2, _tempTex1, _blurMaterial, 3 );
					}

					// Blit to color buffer
					Blitter.BlitCameraTexture( cmd, _tempTex1, _cameraColorBuffer, _volumeLightMaterial, 1 );


					// Set z buffer and blit to color buffer
					// Blitter.BlitCameraTexture( cmd, _cameraDepthBuffer, _cameraColorBuffer, _volumeLightMaterial, 0 );
				}

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

			// calculate hg parameter
			Vector3 CalculateHG( float g ) {
				//(1 - g)^2 / (4 * pi * (1 + g ^2 - 2 * g * cosθ) ^ 1.5 )
				//_MieScatteringFactor.x = (1 - g) ^ 2 / 4 * pi
				//_MieScatteringFactor.y =  1 + g ^ 2
				//_MieScatteringFactor.z =  2 * g
				Vector3 hgPara = new Vector4( ( 1 - g ) * ( 1 - g ) * 0.25f / Mathf.PI, 1 + g * g, 2 * g );
				return hgPara;
			}
		}

		/*************************************************************************/
		CustomRenderPass _volumeLightPass;

		// run when create render feature
		public override void Create() {
			// initialize CustomRenderPass
			_volumeLightPass = new CustomRenderPass( settings ){
				// render volume light before postprocess
				renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing,
			};
		}

		// run when change parameter
		public override void SetupRenderPasses( ScriptableRenderer renderer, in RenderingData renderingData ) {
			if( renderingData.cameraData.cameraType == CameraType.Game ) {
				// claim the input buffer
				_volumeLightPass.ConfigureInput( ScriptableRenderPassInput.Color );
				_volumeLightPass.ConfigureInput( ScriptableRenderPassInput.Depth );
			}
		}

		// run with each camera, inject ScriptableRenderPass 
		public override void AddRenderPasses( ScriptableRenderer renderer, ref RenderingData renderingData ) {
			if( renderingData.cameraData.cameraType == CameraType.Game ) {
				renderer.EnqueuePass( _volumeLightPass );
			}
		}
	}
}