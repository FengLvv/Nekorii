using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Post_Process_Effect.Render_Feature
{
    public class VolumeLight : ScriptableRendererFeature
    {
        [System.Serializable]
        public class Settings
        {
        }

        public Settings settings = new Settings();

        class CustomRenderPass : ScriptableRenderPass
        {
            private Material _volumeLightMaterial;

            RTHandle _cameraDepthBuffer;
            RTHandle _cameraColorBuffer;
            RTHandle _tempTex;
            private RenderTexture a;
            RenderTextureDescriptor m_Descriptor;
            private VolumeLightParameter paramaters;

            //cmd name
            string _passName = "VolumeLightPass";

            //初始类的时候传入材质
            public CustomRenderPass(Settings settings)
            {
                _volumeLightMaterial = Resources.Load<Material>("Volume Light/Volume Light Material");

                // _material = CoreUtils.CreateEngineMaterial(settings.shaderNeeded);

                //input parameter from volume
                // VolumeStack vs = VolumeManager.instance.stack;
                // paramaters = vs.GetComponent<VolumeLightParameter>();
            }

            // execute each frame when set up camera
            // create temp rt
            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {

                // get z-buffer and color buffer
                _cameraDepthBuffer = renderingData.cameraData.renderer.cameraDepthTargetHandle;
                _cameraColorBuffer = renderingData.cameraData.renderer.cameraColorTargetHandle;

                // create temp rt
                m_Descriptor = new RenderTextureDescriptor(Screen.width, Screen.height, RenderTextureFormat.Default, 0)
                {
                    depthBufferBits = 0
                };
                RenderingUtils.ReAllocateIfNeeded(ref _tempTex, m_Descriptor, FilterMode.Bilinear,
                    TextureWrapMode.Clamp, name: "_TempTex");
                
            }

            // execute each frame in render event
            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (_volumeLightMaterial is null)
                {
                    Debug.Log("a");
                    return;
                }

                if (renderingData.cameraData.camera.cameraType != CameraType.Game) return;

                CommandBuffer cmd = CommandBufferPool.Get(name: _passName);

                using (new ProfilingScope(cmd, new ProfilingSampler(cmd.name)))
                {
                    cmd.SetGlobalTexture("_ScreenDepthTexture", _cameraDepthBuffer);
                    Blitter.BlitCameraTexture(cmd, _cameraDepthBuffer, _cameraColorBuffer, _volumeLightMaterial, 0);
                }

                //执行、清空、释放 CommandBuffer
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                CommandBufferPool.Release(cmd);
            }

            //清除任何分配的临时RT
            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                //_tempTex?.Release(); //如果用的RenderingUtils.ReAllocateIfNeeded创建，就不要清除，否则会出bug（纹理传入不了材质）
            }
        }

        /*************************************************************************/
        CustomRenderPass _volumeLightPass;

        // run when create render feature
        public override void Create()
        {
            // initialize CustomRenderPass
            _volumeLightPass = new CustomRenderPass(settings)
            {
                // render volume light before postprocess
                renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing,
            };
        }

        // run when change parameter
        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            if (renderingData.cameraData.cameraType == CameraType.Game)
            {
                // claim the input buffer
                _volumeLightPass.ConfigureInput(ScriptableRenderPassInput.Color);
                _volumeLightPass.ConfigureInput(ScriptableRenderPassInput.Depth);
            }
        }

        // run with each camera, inject ScriptableRenderPass 
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.cameraType == CameraType.Game)
            {
                renderer.EnqueuePass(_volumeLightPass);
            }
        }
    }
}