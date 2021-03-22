using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


//RendererFeature获取法线深度图
public class DepthNormalsFeature : ScriptableRendererFeature
{
    class DepthNormalPass : ScriptableRenderPass//自定义pass
    {
        public Material material = null;
        public RenderTargetHandle targetHandle { get; set; }
        private FilteringSettings m_FilteringSettings;
        ShaderTagId m_ShaderTagId = new ShaderTagId("DepthOnly");
        public DepthNormalPass(RenderQueueRange renderQueueRange,LayerMask layerMask, Material material)
        {
            m_FilteringSettings = new FilteringSettings(renderQueueRange,layerMask);
            this.material = material;
        }

        public void SetUp(RenderTargetHandle targetHandle) //接收render feather传的图
        {
            this.targetHandle = targetHandle;
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

            cmd.GetTemporaryRT(targetHandle.id, descriptor, FilterMode.Point);
            ConfigureTarget(targetHandle.Identifier());
            ConfigureClear(ClearFlag.All, Color.black);
        }

        //这里实现渲染逻辑
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("深度法线获取Pass");
            using (new ProfilingScope(cmd,new ProfilingSampler("DepthNormals Prepass")))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
                var drawSetting = CreateDrawingSettings(m_ShaderTagId, ref renderingData, sortFlags);
                drawSetting.perObjectData = PerObjectData.None;

                ref CameraData cameraData = ref renderingData.cameraData;
                Camera t_Camera = cameraData.camera;
                if (cameraData.isStereoEnabled)
                {
                    context.StartMultiEye(t_Camera);
                }
                drawSetting.overrideMaterial = material;
                context.DrawRenderers(renderingData.cullResults, ref drawSetting, ref m_FilteringSettings);

                cmd.SetGlobalTexture("_CameraDepthNormalsTexture", targetHandle.id);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    DepthNormalPass m_DepthNormalPass;
    RenderTargetHandle m_DepthNormalsTexture;
    Material m_DepthNormalMaterial;

    public override void Create()//进行初始化
    {
        m_DepthNormalMaterial = CoreUtils.CreateEngineMaterial("Hidden/InternalDepthNormalsTexture");
        m_DepthNormalPass = new DepthNormalPass(RenderQueueRange.opaque, -1,m_DepthNormalMaterial);
        m_DepthNormalPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        m_DepthNormalsTexture.Init("_CameraDepthNormalTexture");
    }

    //在这里，你可以在渲染器中注入一个或多个渲染过程。
    //每个摄像头设置一次渲染器，将调用此方法
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_DepthNormalPass.SetUp(m_DepthNormalsTexture);
        renderer.EnqueuePass(m_DepthNormalPass);

    }
}


