using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


//RendererFeature获取法线深度图
public class DepthNormalsFeature : ScriptableRendererFeature
{
    class DepthNormalPass : ScriptableRenderPass//自定义pass
    {
        public RenderTargetHandle destination { get; set; }

        public Material depthNormalsMaterial  = null;
        private FilteringSettings m_FilteringSettings;
        ShaderTagId m_ShaderTagId = new ShaderTagId("DepthOnly");
        public DepthNormalPass(RenderQueueRange renderQueueRange,LayerMask layerMask, Material material)
        {
            m_FilteringSettings = new FilteringSettings(renderQueueRange,layerMask);
            this.depthNormalsMaterial  = material;
        }

        public void SetUp(RenderTargetHandle destination) //接收render feather传的图
        {
            this.destination  = destination;
        }

        //在执行渲染过程之前调用此方法
        //用于配置渲染目标及其清除状态，还可以创建临时渲染目标纹理
        //如果 为空，则此渲染过程将渲染到活动的摄像机渲染目标
        //渲染管道将确保以有效的方式进行目标设置和清除
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            RenderTextureDescriptor descriptor = cameraTextureDescriptor;
            descriptor.depthBufferBits = 32;
            descriptor.colorFormat = RenderTextureFormat.ARGB32;

            cmd.GetTemporaryRT(destination .id, descriptor, FilterMode.Point);
            ConfigureTarget(destination .Identifier());
            ConfigureClear(ClearFlag.All, Color.black);
        }

        //这里实现渲染逻辑
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("DepthNormals Prepass");
            using (new ProfilingScope(cmd,new ProfilingSampler("DepthNormals Prepass")))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
                var drawSetting = CreateDrawingSettings(m_ShaderTagId, ref renderingData, sortFlags);

                drawSetting.perObjectData = PerObjectData.None;

                ref CameraData cameraData = ref renderingData.cameraData;
                Camera camera = cameraData.camera;
                if (cameraData.isStereoEnabled)
                {
                    context.StartMultiEye(camera);
                }

                drawSetting.overrideMaterial = depthNormalsMaterial ;

                context.DrawRenderers(renderingData.cullResults, ref drawSetting, ref m_FilteringSettings);

                cmd.SetGlobalTexture("_CameraDepthNormalsTexture", destination .id);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        //清除在执行此渲染过程期间创建的所有已分配资源
        public override void FrameCleanup(CommandBuffer cmd)
        {
            if(destination  != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(destination .id);
                destination  = RenderTargetHandle.CameraTarget;
            }
        }
    }



    DepthNormalPass depthNormalsPass;
    RenderTargetHandle depthNormalsTexture;
    Material depthNormalsMaterial;

    public override void Create()//进行初始化
    {
        depthNormalsMaterial = CoreUtils.CreateEngineMaterial("Hidden/Internal-DepthNormalsTexture");
        depthNormalsPass = new DepthNormalPass(RenderQueueRange.opaque, -1,depthNormalsMaterial);
        depthNormalsPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        depthNormalsTexture.Init("_CameraDepthNormalTexture");
    }

    //在这里，你可以在渲染器中注入一个或多个渲染过程。
    //每个摄像头设置一次渲染器，将调用此方法
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        depthNormalsPass.SetUp(depthNormalsTexture);
        renderer.EnqueuePass(depthNormalsPass);

    }
}


