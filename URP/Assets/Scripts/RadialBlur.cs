using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RadialBlur : ScriptableRendererFeature
{
    [System.Serializable] public class MySetting//定义一个设置类
    {
        public string passName = "径向模糊";
        public Material myMat;
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;//默认插到透明完成后

        [Range(0, 1)] public float x = 0.5f;
        [Range(0, 1)] public float y = 0.5f;

        [Range(1, 8)] public int loop = 5;
        [Range(1, 8)] public float blur = 3;

        [Range(1, 5)] public int downSample = 2;
        [Range(0, 1)] public float instensity = 0.5f;
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
            cmd.Blit(PassSource, Temp1);//存储降采样的源图，用于pass0
            cmd.Blit(PassSource, Temp2);
        }
    }

    CustomRenderPass myPass;

    public override void Create()//进行初始化
    {
        myPass = new CustomRenderPass(setting.passName);//实例化一下并传参数name就是tag
        myPass.renderPassEvent = setting.passEvent;
        myPass.passBulr = setting.bulr;
        myPass.passLoop = setting.loop;
        myPass.passMat = setting.myMat;
        myPass.passDownSample = setting.downSample;
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var src = renderer.cameraColorTarget;
        myPass.SetUp(src);
        renderer.EnqueuePass(myPass);
    }
}


