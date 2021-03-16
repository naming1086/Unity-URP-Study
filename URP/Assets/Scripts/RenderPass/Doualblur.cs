using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class Doualblur : ScriptableRendererFeature
{
    [System.Serializable] public class MySetting//定义一个设置类
    {
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;//默认插到透明完成后
        public Material myMat;
        [Range(1, 8)] public int downSample = 2;
        [Range(2, 8)] public int loop = 2;
        [Range(0.5f, 5)] public float bulr = 0.5f;
        public string passTag = "双重模糊";
    }

    public MySetting setting = new MySetting();

    class CustomRenderPass : ScriptableRenderPass//自定义pass
    {
        public Material passMat = null;
        public int passDownSample = 2;//降采样
        public int passLoop = 2;//模糊的迭代次数
        public float passBulr = 4;
        private RenderTargetIdentifier passSource { get; set; }//源图像，目标图像
        RenderTargetIdentifier buffer1;//临时图像1
        RenderTargetIdentifier buffer2;//临时图像2
        string passTag;

        struct Level
        {
            public int down;
            public int up;
        }

        Level[] my_Level;
        int maxLevel = 16;//指定一个最大值来限制申请的ID的数量，这里限制到16个

        public CustomRenderPass(string tag)
        {
            this.passTag = tag;
        }

        public void SetUp(RenderTargetIdentifier source) //接收render feather传的图
        {
            this.passSource = source;
            my_Level = new Level[maxLevel];
            for (int t = 0; t < maxLevel; t++)//申请32个ID的，up和down各16个，用这个id去代替替换临时RT来使用
            {
                my_Level[t] = new Level
                {
                    down = Shader.PropertyToID("_BlurMipDown" + t),
                    up = Shader.PropertyToID("_BlurMipUp" + t)
                };
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            int bufferId1 = Shader.PropertyToID("bufferBlur1");
            int bufferId2 = Shader.PropertyToID("bufferBlur2");

            CommandBuffer cmd = CommandBufferPool.Get(passTag);//定义cmd
            passMat.SetFloat("_Blur", passBulr);//指定材质参数
            //cmd.SetGlobalFloat("_Blur", passBulr);//设置模糊，全局设置

            RenderTextureDescriptor opaquedesc = renderingData.cameraData.cameraTargetDescriptor;

            int width = opaquedesc.width / passDownSample;
            int height = opaquedesc.height / passDownSample;
            opaquedesc.depthBufferBits = 0;

            //down
            RenderTargetIdentifier lastDown = passSource;//把初始图像作为lastDown的起始图去计算
            for (int t = 0; t < passLoop; t++)
            {
                int midDown = my_Level[t].down;//middle down,即间接计算down的工具人ID
                int midUp = my_Level[t].up;//middle up,即间接计算up的工具人ID
                cmd.GetTemporaryRT(midDown, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);//对指定高宽申请RT，每个循环的指定RT都会变小为原来一半
                cmd.GetTemporaryRT(midUp, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);

                cmd.Blit(lastDown, midDown, passMat, 0);//计算down的pass
                lastDown = midDown;//工具人辛苦了
                width = Mathf.Max(width / 2, 1);//每次循环都降尺寸
                height = Mathf.Max(height / 2, 1);
            }

            //up
            int lastUp = my_Level[passLoop - 1].down;//把down的最后一次图像当成up的第一张图去计算up
            for (int j = passLoop - 2; j >= 0; j--)//这里减2是因为第一次已经有了要减去1，但第一次是直接复制的，所以循环完后得补一次up
            {
                int midUp = my_Level[j].up;
                cmd.Blit(lastUp, midUp, passMat);//这里直接开干就是因为在down过程中以及把RT得位置霸占好了，这里直接使用
                lastUp = midUp;//工具人辛苦了
            }

            cmd.Blit(lastUp, passSource, passMat);//补一次up，顺便就输出了

            context.ExecuteCommandBuffer(cmd);//执行命令缓冲区的该命令
            CommandBufferPool.Release(cmd);//释放cmd
            for (int k = 0; k < passLoop; k++)//清RT，防止内存泄漏
            {
                cmd.ReleaseTemporaryRT(my_Level[k].up);
                cmd.ReleaseTemporaryRT(my_Level[k].down);
            }
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


