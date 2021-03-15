using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class KawaseBlur : ScriptableRendererFeature
{
    [System.Serializable] public class MySetting//定义一个设置类
    {
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;//默认插到透明完成后
        public Material myMat;
        [Range(2, 10)] public int downSample = 2;
        [Range(2, 10)] public int loop = 2;
        [Range(0.5f, 5)] public float bulr = 0.5f;
        public string passTag = "KawaseBlur";
    }

    public MySetting setting = new MySetting();

    class CustomRenderPass : ScriptableRenderPass//自定义pass
    {
        public Material passMat = null;
        public int passDownSample = 2; //降采样
        public int passLoop = 2;//模糊的迭代次数
        public float passBulr = 4;
        private RenderTargetIdentifier passSource { get; set; }//源图像，目标图像
        RenderTargetIdentifier buffer1;//临时图像1
        RenderTargetIdentifier buffer2;//临时图像2
        string passTag;

        public CustomRenderPass(string tag)
        {
            this.passTag = tag;
        }

        public void SetUp(RenderTargetIdentifier source) //接收render feather传的图
        {
            this.passSource = source;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            int bufferId1 = Shader.PropertyToID("bufferBlur1");
            int bufferId2 = Shader.PropertyToID("bufferBlur2");

            CommandBuffer cmd = CommandBufferPool.Get(passTag);
            RenderTextureDescriptor opaquedesc = renderingData.cameraData.cameraTargetDescriptor;

            int width = opaquedesc.width / passDownSample;
            int height = opaquedesc.height / passDownSample;
            opaquedesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(bufferId1, width,height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);
            cmd.GetTemporaryRT(bufferId2, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);

            buffer1 = new RenderTargetIdentifier(bufferId1);
            buffer2 = new RenderTargetIdentifier(bufferId2);

            cmd.SetGlobalFloat("_Blur", 1f);
            cmd.Blit(passSource, buffer1,passMat);

            for (int t = 1; t < passLoop; t++)
            {
                cmd.SetGlobalFloat("_Blur", t * passBulr + 1);
                cmd.Blit(buffer1, buffer2, passMat);
                var temRT = buffer1;
                buffer1 = buffer2;
                buffer2 = temRT;
            }

            cmd.SetGlobalFloat("_Blur", passLoop * passBulr + 1);
            cmd.Blit(buffer1, passSource, passMat);

            context.ExecuteCommandBuffer(cmd);//执行命令缓冲区的该命令
            CommandBufferPool.Release(cmd);//释放该命令
        }
    }

    CustomRenderPass myPass;

    public override void Create()//进行初始化
    {
        myPass = new CustomRenderPass(setting.passTag);//实例化一下并传参数name就是tag
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


