using System;
using System.Linq;
using Unity.Mathematics;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RendererUtils;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

namespace Post_Process_Effect.Render_Feature {
	public class Gas : ScriptableRendererFeature {
		[System.Serializable]
		public class Settings {
			[Header( "Fluid" )]
			public float viscosity = 0.1f;
			public float advectionSpeed = 100F;
			public Vector3 forcePosition = new Vector3( 32, 32, 32 );
			public Vector3 forceDir = new Vector3( 0, 1, 0 );
			public int viscosityIterations = 10;
			public int pressureIterations = 10;
			[Range(0,10)]
			public float gravity = 10f;

			[Header( "Render" )]
			public Vector3 fluidCenter = new Vector3( -83, 255, -44.7f );
			public float fluidSize = 3;
			public float fluidDensityMultiply = 0.5f;
			public Color gasColor = new Color( 0.5f, 0.5f, 0.5f, 1 );

			[Header( "Sphere" )]
			public Vector3 sphereCenter = new Vector3( 32, 32, 32 );
			public float sphereRadius = 10;
		}

		public Settings settings = new Settings();

		class CustomRenderPass : ScriptableRenderPass {
			RTHandle _cameraColor;
			RTHandle _cameraDepth;

			ComputeShader _computeFluid;
			Material _fluidSample;
			RenderTexture _vel1;
			RenderTexture _vel2;
			RenderTexture _pressure;
			RenderTexture _density;
			float _advectionSpeed;
			float _viscosity;
			Vector3 _forcePosition;
			Vector3 _forceDir;

			//cmd name
			string _passName = "GasSimulation";
			Settings _settings;

			bool _isInitialized;


			Vector3 _center;
			float _size;

			//初始类的时候传入材质
			public CustomRenderPass( Settings settings ) {
				_vel1 = Resources.Load<RenderTexture>( "Texture/Gas/velocity1" );
				_vel2 = Resources.Load<RenderTexture>( "Texture/Gas/velocity2" );
				_pressure = Resources.Load<RenderTexture>( "Texture/Gas/pressure" );
				_density = Resources.Load<RenderTexture>( "Texture/Gas/density" );
				_computeFluid = Resources.Load<ComputeShader>( "Shader/DrawFluid" );
				_fluidSample = Resources.Load<Material>( "Shader/Custom_FluidSample" );
				this._settings = settings;
			}

			// execute each frame when set up camera
			// create temp rt
			public override void OnCameraSetup( CommandBuffer cmd, ref RenderingData renderingData ) {
				_cameraColor = renderingData.cameraData.renderer.cameraColorTargetHandle;
				_cameraDepth = renderingData.cameraData.renderer.cameraDepthTargetHandle;
				// get z-buffer and color buffer
				ConfigureClear( ClearFlag.None, Color.black );
				_forceDir = _settings.forceDir;
				_forcePosition = _settings.forcePosition;
				_viscosity = _settings.viscosity;
				_advectionSpeed = _settings.advectionSpeed;
				_center = _settings.fluidCenter;
				_size = _settings.fluidSize;
			}

			// execute each frame in render event
			public override void Execute( ScriptableRenderContext context, ref RenderingData renderingData ) {
				CommandBuffer cmd = CommandBufferPool.Get( name:_passName );
				using( new ProfilingScope( cmd, new ProfilingSampler( cmd.name ) ) ) {
					// 8 clear
					if( !_isInitialized ) {
						cmd.SetComputeTextureParam( _computeFluid, 8, Pressure, _pressure );
						cmd.SetComputeTextureParam( _computeFluid, 8, Velocity1, _vel1 );
						cmd.SetComputeTextureParam( _computeFluid, 8, Velocity2, _vel2 );
						cmd.SetComputeTextureParam( _computeFluid, 8, Density, _density );
						cmd.DispatchCompute( _computeFluid, 8, 64 / 8, 64 / 8, 64 / 8 );
						_isInitialized = true;
					}

					// parameters
					cmd.SetComputeVectorParam( _computeFluid, "_TexDim", new Vector3( 64, 64, 64 ) );
					cmd.SetComputeFloatParam( _computeFluid, Dt, Time.deltaTime );
					cmd.SetComputeFloatParam( _computeFluid, Viscosity, _viscosity );
					cmd.SetComputeFloatParam( _computeFluid, AdvectionSpeed, _advectionSpeed );
					cmd.SetComputeVectorParam( _computeFluid, ForcePos, _forcePosition );
					cmd.SetComputeVectorParam( _computeFluid, ForceDir, _forceDir );
					cmd.SetComputeVectorParam( _computeFluid, "_BlockSpherePos", _settings.sphereCenter );
					cmd.SetComputeFloatParam( _computeFluid, "_BlockSphereRadius", _settings.sphereRadius );


					// 0 Advection
					cmd.SetComputeTextureParam( _computeFluid, 0, Velocity1, _vel1 );
					cmd.SetComputeTextureParam( _computeFluid, 0, Velocity2, _vel2 );
					cmd.DispatchCompute( _computeFluid, 0, 64 / 8, 64 / 8, 64 / 8 );

					// 1 2 Viscosity : Jacobi Iteration
					cmd.SetComputeTextureParam( _computeFluid, 1, Velocity1, _vel1 );
					cmd.SetComputeTextureParam( _computeFluid, 1, Velocity2, _vel2 );
					cmd.SetComputeTextureParam( _computeFluid, 2, Velocity1, _pressure );
					cmd.SetComputeTextureParam( _computeFluid, 2, Velocity2, _pressure );
					for( int i = 0; i < _settings.viscosityIterations; i++ ) {
						cmd.DispatchCompute( _computeFluid, 1, 64 / 8, 64 / 8, 64 / 8 );
						cmd.DispatchCompute( _computeFluid, 2, 64 / 8, 64 / 8, 64 / 8 );
					}

					
					// 3 Force
					cmd.SetComputeFloatParam( _computeFluid, "_Gravity", _settings.gravity );
					cmd.SetComputeTextureParam( _computeFluid, 3, Velocity2, _vel2 );
					cmd.DispatchCompute( _computeFluid, 3, 64 / 8, 64 / 8, 64 / 8 );

					// 4 Divergence						
					cmd.SetComputeTextureParam( _computeFluid, 4, Velocity2, _vel2 );
					cmd.SetComputeTextureParam( _computeFluid, 4, Pressure, _pressure );
					cmd.DispatchCompute( _computeFluid, 4, 64 / 8, 64 / 8, 64 / 8 );

					// Pressure : Jacobi Iteration
					cmd.SetComputeTextureParam( _computeFluid, 5, Pressure, _pressure );
					cmd.SetComputeTextureParam( _computeFluid, 6, Pressure, _pressure );
					for( int i = 0; i < _settings.pressureIterations; i++ ) {
						cmd.DispatchCompute( _computeFluid, 5, 64 / 8, 64 / 8, 64 / 8 );
						cmd.DispatchCompute( _computeFluid, 6, 64 / 8, 64 / 8, 64 / 8 );
					}

					// 7 Gradient
					cmd.SetComputeTextureParam( _computeFluid, 7, Pressure, _pressure );
					cmd.SetComputeTextureParam( _computeFluid, 7, Velocity1, _vel1 );
					cmd.SetComputeTextureParam( _computeFluid, 7, Velocity2, _vel2 );
					cmd.DispatchCompute( _computeFluid, 7, 64 / 8, 64 / 8, 64 / 8 );

					// 9 density
					cmd.SetComputeTextureParam( _computeFluid, 9, Velocity1, _vel1 );
					cmd.SetComputeTextureParam( _computeFluid, 9, Density, _density );
					cmd.DispatchCompute( _computeFluid, 9, 64 / 8, 64 / 8, 64 / 8 );

					// Draw
					cmd.SetComputeVectorParam( _computeFluid, "_GasColor", new Vector4( _settings.gasColor.r, _settings.gasColor.g, _settings.gasColor.b, _settings.gasColor.a ) );
					cmd.SetGlobalVector( "_FluidCenter", _center );
					cmd.SetGlobalFloat( "_FluidSize", _size );
					cmd.SetGlobalTexture( "_GasVelocity", _density );
					cmd.SetGlobalFloat( "_DensityMultiply", _settings.fluidDensityMultiply );
					Blitter.BlitCameraTexture( cmd, _cameraDepth, _cameraColor, _fluidSample, 0 );
				}

				context.ExecuteCommandBuffer( cmd );
				cmd.Clear();
				CommandBufferPool.Release( cmd );
			}

			//清除任何分配的临时RT
			public override void OnCameraCleanup( CommandBuffer cmd ) {
				//_tempTex?.Release(); //如果用的RenderingUtils.ReAllocateIfNeeded创建，就不要清除，否则会出bug（纹理传入不了材质）
			}
		}

		/*************************************************************************/
		CustomRenderPass _gasPass;
		readonly static int Velocity1 = Shader.PropertyToID( "_Velocity1" );
		readonly static int Velocity2 = Shader.PropertyToID( "_Velocity2" );
		readonly static int Pressure = Shader.PropertyToID( "_Pressure" );
		readonly static int Dt = Shader.PropertyToID( "_Dt" );
		readonly static int Viscosity = Shader.PropertyToID( "_Viscosity" );
		readonly static int AdvectionSpeed = Shader.PropertyToID( "_AdvectionSpeed" );
		readonly static int ForcePos = Shader.PropertyToID( "_ForcePos" );
		readonly static int Density = Shader.PropertyToID( "_Density" );
		readonly static int ForceDir = Shader.PropertyToID( "_ForceDir" );

		// run when create render feature
		public override void Create() {
			// initialize CustomRenderPass
			_gasPass = new CustomRenderPass( settings ){
				// render volume light before postprocess
				renderPassEvent = RenderPassEvent.BeforeRenderingTransparents,
			};
		}

		// run when change parameter
		public override void SetupRenderPasses( ScriptableRenderer renderer, in RenderingData renderingData ) {
			if( renderingData.cameraData.cameraType == CameraType.Game ) {
				// claim the input buffer
				_gasPass.ConfigureInput( ScriptableRenderPassInput.Color );
				_gasPass.ConfigureInput( ScriptableRenderPassInput.Depth );
				_gasPass.ConfigureInput( ScriptableRenderPassInput.Normal );
			}
		}

		// run with each camera, inject ScriptableRenderPass 
		public override void AddRenderPasses( ScriptableRenderer renderer, ref RenderingData renderingData ) {
			if( renderingData.cameraData.cameraType == CameraType.Game ) {
				renderer.EnqueuePass( _gasPass );
			}
		}
	}
}