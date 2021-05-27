using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class URPRadiaBlur : ScriptableRendererFeature
{
    [System.Serializable] public class MySetting//定义一个设置类
    {
        public string passName = "径向模糊";
        public Material myMat = null;
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;//默认插到透明完成后

        [Range(0, 1)] public float x = 0.5f;//径向模糊的中心水平位置
        [Range(0, 1)] public float y = 0.5f;//径向模糊的竖直方向位置

        [Range(1, 8)] public int loop = 5;//迭代次数
        [Range(1, 8)] public float blur = 3;//模糊采样的距离

        [Range(1, 5)] public int downSample = 2;//降采样的程度
        [Range(0, 1)] public float instensity = 0.5f;//模糊强度，0为不模糊，1为全模糊，用于过渡调整
    }

    public MySetting setting = new MySetting();

    class CustomRenderPass : ScriptableRenderPass//自定义pass
    {
        public Material passMat = null;
        public string name;
        public float x;
        public float y;
        public int loop;
        public float instensity;
        public float blur;
        public int downSample;
        public RenderTargetIdentifier PassSource { get; set; }
        public RenderTargetIdentifier BlurTex;
        public RenderTargetIdentifier Temp1;
        public RenderTargetIdentifier Temp2;
        int ssW;
        int ssH;

        public void SetUp(RenderTargetIdentifier source) //接收render feather传的图
        {
            this.PassSource = source;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            int BlurTexID = Shader.PropertyToID("_BlurTex");
            int TempID1 = Shader.PropertyToID("Temp1");
            int TempID2 = Shader.PropertyToID("_SourceTex");
            int LoopID = Shader.PropertyToID("_Loop");
            int XID = Shader.PropertyToID("_X");
            int YID = Shader.PropertyToID("_Y");
            int BlurID = Shader.PropertyToID("_Blur");
            int InstensityID = Shader.PropertyToID("_Instensity");

            RenderTextureDescriptor SSdesc = renderingData.cameraData.cameraTargetDescriptor;
            ssH = SSdesc.height / downSample;
            ssW = SSdesc.width / downSample;
            CommandBuffer cmd = CommandBufferPool.Get(name);
            cmd.GetTemporaryRT(TempID1, ssW, ssH, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);//用来存降采样
            cmd.GetTemporaryRT(BlurTexID, SSdesc);//模糊图
            cmd.GetTemporaryRT(TempID2, SSdesc);
            BlurTex = new RenderTargetIdentifier(BlurTexID);
            Temp1 = new RenderTargetIdentifier(TempID1);
            Temp2 = new RenderTargetIdentifier(TempID2);
            cmd.SetGlobalFloat(LoopID, loop);
            cmd.SetGlobalFloat(XID, x);
            cmd.SetGlobalFloat(YID, y);
            cmd.SetGlobalFloat(BlurID, blur);
            cmd.SetGlobalFloat(InstensityID, instensity);
            cmd.Blit(PassSource, Temp1);//存储降采样的源图，用于pass0计算
            cmd.Blit(PassSource, Temp2);//存储源图，用于计算pass1的混合
            cmd.Blit(Temp1, BlurTex, passMat, 0);//pass0的模糊计算
            cmd.Blit(BlurTex, PassSource, passMat, 1);//pass1的混合
            context.ExecuteCommandBuffer(cmd);
            cmd.ReleaseTemporaryRT(BlurTexID);
            cmd.ReleaseTemporaryRT(TempID1);
            cmd.ReleaseTemporaryRT(TempID2);
            CommandBufferPool.Release(cmd);
        }
    }

    CustomRenderPass m_ScriptablePass;

    public override void Create()//进行初始化
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.renderPassEvent = setting.passEvent;
        m_ScriptablePass.blur = setting.blur;
        m_ScriptablePass.x = setting.x;
        m_ScriptablePass.y = setting.y;
        m_ScriptablePass.instensity = setting.instensity;
        m_ScriptablePass.loop = setting.loop;
        m_ScriptablePass.passMat = setting.myMat;
        m_ScriptablePass.name = setting.passName;
        m_ScriptablePass.downSample = setting.downSample;
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(setting.myMat != null) 
        {
            m_ScriptablePass.SetUp(renderer.cameraColorTarget);
            renderer.EnqueuePass(m_ScriptablePass);
        }
        else 
        {
            Debug.LogError("径向模糊材质球丢失");
        }
    }
}


