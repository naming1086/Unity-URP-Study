using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
public class OutlinePass : ScriptableRendererFeature
{
    [System.Serializable]
    public class MySetting//定义一个设置类
    {
        public string name = "外描边";
        //后处理材质
        public Material material;
        //渲染通过事件
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;//默认插到透明完成后

        public int scale = 1;
        public Color color = Color.white;
        public float depthThreshold = 1.5f;
        public float depthNormalThreshold = 0.5f;
        public float depthNormalThresholdScale = 7;
        public float normalThreshold = 0.4f;

    }

    public MySetting setting = new MySetting();

    class CustomRenderPass : ScriptableRenderPass
    {
        public string name;
        public Material material = null;
        public FilterMode filterMode { get; set; }//图像的模式

        public float scale = 1;
        public Color color = Color.white;
        public float depthThreshold = 1.5f;
        public float depthNormalThreshold = 0.5f;
        public float depthNormalThresholdScale = 7;
        public float normalThreshold = 0.4f;

        RenderTargetIdentifier m_TargetIdentifier { get; set; }//源图像，目标图像
        RenderTargetHandle m_TargetHandle;

        public void SetUp(RenderTargetIdentifier targetIdentifier) //接收render feather传的图
        {
            this.m_TargetIdentifier = targetIdentifier;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            int ScaleID = Shader.PropertyToID("_Scale");
            int ColorID = Shader.PropertyToID("_Color");
            int DepthThresholdID = Shader.PropertyToID("_DepthThreshold");
            int DepthNormalThresholdID = Shader.PropertyToID("_DepthNormalThreshold");
            int DepthNormalThresholdScaleID = Shader.PropertyToID("_DepthNormalThresholdScale");
            int NormalThresholdID = Shader.PropertyToID("_NormalThreshold");

            CommandBuffer cmd = CommandBufferPool.Get(name);
            cmd.SetGlobalFloat(ScaleID, scale);
            cmd.SetGlobalColor(ColorID, color);
            cmd.SetGlobalFloat(DepthThresholdID, depthThreshold);
            cmd.SetGlobalFloat(DepthNormalThresholdID, depthNormalThreshold);
            cmd.SetGlobalFloat(DepthNormalThresholdScaleID, depthNormalThresholdScale);
            cmd.SetGlobalFloat(NormalThresholdID, normalThreshold);

            RenderTextureDescriptor SSdesc = renderingData.cameraData.cameraTargetDescriptor;

            Matrix4x4 clipToView = GL.GetGPUProjectionMatrix(renderingData.cameraData.camera.projectionMatrix, true).inverse;
            cmd.SetGlobalMatrix("_ClipToView", clipToView);

            SSdesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(m_TargetHandle.id, SSdesc, filterMode);//申请一个临时图像
            Blit(cmd, m_TargetIdentifier, m_TargetHandle.Identifier(), material, 0);//把源贴图输入到材质对应的pass里处理，并把处理结果的图像存储到临时图像
            Blit(cmd, m_TargetHandle.Identifier(), m_TargetIdentifier);//然后把临时图像又存储到源图像里
            context.ExecuteCommandBuffer(cmd);//执行命令缓冲区的该命令
            CommandBufferPool.Release(cmd);//释放该命令
            cmd.ReleaseTemporaryRT(m_TargetHandle.id);//释放临时图像
        }
    }
    CustomRenderPass m_ScriptablePass;

    public override void Create()//进行初始化
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.renderPassEvent = setting.renderPassEvent;
        m_ScriptablePass.name = setting.name;
        m_ScriptablePass.material = setting.material;
        m_ScriptablePass.scale = setting.scale;
        m_ScriptablePass.color = setting.color;
        m_ScriptablePass.depthThreshold = setting.depthThreshold;
        m_ScriptablePass.depthNormalThreshold = setting.depthNormalThreshold;
        m_ScriptablePass.depthNormalThresholdScale = setting.depthNormalThresholdScale;
        m_ScriptablePass.normalThreshold = setting.normalThreshold;
}

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var src = renderer.cameraColorTarget;
        m_ScriptablePass.SetUp(src);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}
