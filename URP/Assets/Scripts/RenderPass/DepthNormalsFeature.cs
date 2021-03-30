using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/*
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
        //depthNormalsMaterial = CoreUtils.CreateEngineMaterial("Hidden/Roystan/Normals Texture");
        depthNormalsPass = new DepthNormalPass(RenderQueueRange.opaque, -1,depthNormalsMaterial);
        depthNormalsPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        depthNormalsTexture.Init("_CameraDepthNormalsTexture");
    }

    //在这里，你可以在渲染器中注入一个或多个渲染过程。
    //每个摄像头设置一次渲染器，将调用此方法
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        depthNormalsPass.SetUp(depthNormalsTexture);
        renderer.EnqueuePass(depthNormalsPass);

    }
}
*/

public class DepthNormalsFeature : ScriptableRendererFeature
{
    class DepthNormalsPass : ScriptableRenderPass
    {
        // 深度缓冲块大小
        int kDepthBufferBits = 32;
        /// <summary>深度法线纹理</summary>
        private RenderTargetHandle depthAttachmentHandle { get; set; }
        /// <summary>目标相机渲染信息</summary>
        internal RenderTextureDescriptor descriptor { get; private set; }

        /// <summary>材质</summary>
        private Material depthNormalsMaterial = null;
        /// <summary>筛选设置</summary>
        private FilteringSettings m_FilteringSettings;

        // 该Pass在帧分析器显示的标签
        string m_ProfilerTag = "Depth Normals Pre Pass";
        // Pass绘制标签，在Shader中只有声明了相同绘制标签的Pass才能被调用绘制
        ShaderTagId m_ShaderTagId = new ShaderTagId("DepthOnly");

        /// <summary>
        /// 构造函数
        /// </summary>
        /// <param name="renderQueueRange">渲染队列</param>
        /// <param name="layerMask">渲染对象层级</param>
        /// <param name="material">材质</param>
        public DepthNormalsPass(RenderQueueRange renderQueueRange, LayerMask layerMask, Material material)
        {
            m_FilteringSettings = new FilteringSettings(renderQueueRange, layerMask);
            depthNormalsMaterial = material;
        }

        /// <summary>
        /// 参数设置
        /// </summary>
        /// <param name="baseDescriptor">目标相机渲染信息</param>
        /// <param name="depthAttachmentHandle">深度法线纹理</param>
        public void Setup(RenderTextureDescriptor baseDescriptor, RenderTargetHandle depthAttachmentHandle)
        {
            // 设置纹理
            this.depthAttachmentHandle = depthAttachmentHandle;
            // 设置渲染目标信息
            baseDescriptor.colorFormat = RenderTextureFormat.ARGB32;
            baseDescriptor.depthBufferBits = kDepthBufferBits;
            descriptor = baseDescriptor;
        }

        // 该方法在执行渲染通道之前被调用。
        // 它可以用来配置渲染目标和它们的清除状态。也创建临时渲染目标纹理。
        // 当为空时，这个渲染通道将渲染到激活的摄像机渲染目标。
        // 你不应该调用CommandBuffer.SetRenderTarget。调用<c>ConfigureTarget</c> and <c> configurecclear </c>。
        // 渲染管道将确保目标设置和清除以性能方式进行。
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            // 获取一个临时RT（深度法线纹理、目标信息、滤波模式）
            cmd.GetTemporaryRT(depthAttachmentHandle.id, descriptor, FilterMode.Point);
            // 配置目标
            ConfigureTarget(depthAttachmentHandle.Identifier());
            // 清楚未渲染配置为黑色
            ConfigureClear(ClearFlag.All, Color.black);
        }

        //这里你可以实现渲染逻辑。
        //使用<c>ScriptableRenderContext</c>来发出绘图命令或执行命令缓冲区
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        //你不必调用ScriptableRenderContext。提交时，渲染管道会在管道中的特定点调用它。
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // 获取命令缓冲区
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);

            using (new ProfilingScope(cmd, new ProfilingSampler(m_ProfilerTag)))
            {
                // 执行命令缓存
                context.ExecuteCommandBuffer(cmd);
                // 清楚数据缓存
                cmd.Clear();

                // 相机的排序标志
                var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
                // 创建绘制设置
                var drawSettings = CreateDrawingSettings(m_ShaderTagId, ref renderingData, sortFlags);
                // 设置对象数据
                drawSettings.perObjectData = PerObjectData.None;

                // 检测是否是VR设备
                ref CameraData cameraData = ref renderingData.cameraData;
                Camera camera = cameraData.camera;
                if (cameraData.isStereoEnabled)
                    context.StartMultiEye(camera);

                // 设置覆盖材质
                drawSettings.overrideMaterial = depthNormalsMaterial;

                // 绘制渲染器
                context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref m_FilteringSettings);

                // 设置全局纹理
                cmd.SetGlobalTexture("_CameraDepthNormalsTexture", depthAttachmentHandle.id);
            }
            // 执行命令缓冲区
            context.ExecuteCommandBuffer(cmd);
            // 释放命令缓冲区
            CommandBufferPool.Release(cmd);
        }

        // 清除此呈现传递执行期间创建的任何已分配资源。
        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (depthAttachmentHandle != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(depthAttachmentHandle.id);
                depthAttachmentHandle = RenderTargetHandle.CameraTarget;
            }
        }
    }
    // 深度法线Pass
    DepthNormalsPass depthNormalsPass;
    // 深度法线纹理
    RenderTargetHandle depthNormalsTexture;
    // 处理材质
    Material depthNormalsMaterial;

    public override void Create()
    {
        // 通过Built-it管线中的Shader创建材质
        depthNormalsMaterial = CoreUtils.CreateEngineMaterial("Hidden/Internal-DepthNormalsTexture");
        // 获取Pass（渲染队列，渲染对象，材质）
        depthNormalsPass = new DepthNormalsPass(RenderQueueRange.opaque, -1, depthNormalsMaterial);
        // 设置渲染时机 = 预渲染通道后
        depthNormalsPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        // 设置纹理名
        depthNormalsTexture.Init("_CameraDepthNormalsTexture");
    }

    //这里你可以在渲染器中注入一个或多个渲染通道。
    //这个方法在设置渲染器时被调用。
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // 对Pass进行参数设置（当前渲染相机信息，深度法线纹理）
        depthNormalsPass.Setup(renderingData.cameraData.cameraTargetDescriptor, depthNormalsTexture);
        // 写入渲染管线队列
        renderer.EnqueuePass(depthNormalsPass);
    }
}



