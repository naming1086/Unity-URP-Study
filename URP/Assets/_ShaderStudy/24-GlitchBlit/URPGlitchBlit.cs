using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class URPGlitchBlit : ScriptableRendererFeature
{
    [System.Serializable] public class MySetting//定义一个设置类
    {
        public Material material = null;
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        [Range(0, 1)] public float instensity = 0.5f;
    }
    public MySetting setting = new MySetting();

    class GlitchColorSplitPass : ScriptableRenderPass//自定义pass
    {
        MySetting setting;
        public RenderTargetIdentifier PassSource { get; set; }

        public void SetUp(RenderTargetIdentifier source) //接收render feather传的图
        {
            this.PassSource = source;
        }

        public GlitchColorSplitPass(MySetting setting)
        {
            this.setting = setting;
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            setting.material.SetFloat("_Instensity", setting.instensity);
            CommandBuffer cmd = CommandBufferPool.Get("GlitchColorSplit");
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            int sourID = Shader.PropertyToID("_SourTex");
            cmd.GetTemporaryRT(sourID, desc);
            cmd.CopyTexture(PassSource, sourID);
            cmd.Blit(sourID, PassSource, setting.material);
            context.ExecuteCommandBuffer(cmd);
            cmd.ReleaseTemporaryRT(sourID);
            CommandBufferPool.Release(cmd);
        }
    }

    GlitchColorSplitPass m_GlitchColorSplitPass;

    public override void Create()//进行初始化
    {
        m_GlitchColorSplitPass = new GlitchColorSplitPass(setting);
        m_GlitchColorSplitPass.renderPassEvent = setting.Event;
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_GlitchColorSplitPass.SetUp(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_GlitchColorSplitPass);
    }
}


