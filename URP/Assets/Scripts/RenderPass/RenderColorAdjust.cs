using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class RenderColorAdjust : ScriptableRendererFeature
{
    [System.Serializable] public class MySetting//定义一个设置类
    {
        public ComputeShader CS = null;
        [Tooltip("灰度"),Range(0, 2)] public float saturete = 1;
        [Tooltip("饱和度"), Range(0, 2)] public float bright = 1;
        [Tooltip("对比度"), Range(-2, 3)] public float constrast = 1;
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingTransparents;
    }
    public MySetting setting = new MySetting();

    class CustomRenderPass : ScriptableRenderPass//自定义pass
    {
        private ComputeShader CS;
        private MySetting setting;
        private RenderTargetIdentifier sour;

        public void SetUp(RenderTargetIdentifier source) //接收render feather传的图
        {
            this.sour = source;
        }

        public CustomRenderPass(MySetting setting)
        {
            this.setting = setting;
            this.CS = setting.CS;
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("ColorAdjust");
            int tempID = Shader.PropertyToID("temp1");
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.enableRandomWrite = true;
            cmd.GetTemporaryRT(tempID, desc);
            cmd.SetComputeFloatParam(CS, "_Bright", setting.bright);
            cmd.SetComputeFloatParam(CS, "_Saturate", setting.saturete);
            cmd.SetComputeFloatParam(CS, "_Constrast", setting.constrast);
            cmd.SetComputeTextureParam(CS,0, "_Result", tempID);
            cmd.SetComputeTextureParam(CS,0, "_Sour", sour);
            cmd.DispatchCompute(CS, 0, (int)desc.width / 8, (int)desc.height / 8, 1);
            cmd.Blit(tempID,sour);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    CustomRenderPass m_CustomRenderPass;

    public override void Create()//进行初始化
    {
        m_CustomRenderPass = new CustomRenderPass(setting);
        m_CustomRenderPass.renderPassEvent = setting.Event;
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_CustomRenderPass.SetUp(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_CustomRenderPass);
    }
}


