using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class URPPost : ScriptableRendererFeature
{
    [System.Serializable]public class MySetting//定义一个设置类
    {
        //渲染通过事件
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;//默认插到透明完成后
        //后处理材质
        public Material myMat;
        public int matPassIndex = -1;
    }

    public MySetting setting = new MySetting();

    class CustomRenderPass : ScriptableRenderPass//自定义pass
    {
        public Material passMat = null;
        public int passMatInt = 0;
        public FilterMode passFiltermode { get; set; }//图像的模式
        private RenderTargetIdentifier passSource { get; set; }//源图像，目标图像
        RenderTargetHandle passTempleColorTex;//临时计算图像
        string passTag;

        public CustomRenderPass(RenderPassEvent passEvent,Material material,int passInt,string tag)
        {
            this.renderPassEvent = passEvent;
            this.passMat = material;
            this.passMatInt = passInt;
            this.passTag = tag;
        }

        public void SetUp(RenderTargetIdentifier source) //接收render feather传的图
        {
            this.passSource = source;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(passTag);
            RenderTextureDescriptor opaquedesc = renderingData.cameraData.cameraTargetDescriptor;
            opaquedesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(passTempleColorTex.id, opaquedesc, passFiltermode);//申请一个临时图像
            Blit(cmd, passSource, passTempleColorTex.Identifier(), passMat, passMatInt);//把源贴图输入到材质对应的pass里处理，并把处理结果的图像存储到临时图像
            Blit(cmd, passTempleColorTex.Identifier(), passSource);//然后把临时图像又存储到源图像里
            context.ExecuteCommandBuffer(cmd);//执行命令缓冲区的该命令
            CommandBufferPool.Release(cmd);//释放该命令
            cmd.ReleaseTemporaryRT(passTempleColorTex.id);//释放临时图像
        }
    }

    CustomRenderPass myPass;

    public override void Create()//进行初始化
    {
        int passInt = setting.myMat == null ? 1 : setting.myMat.passCount - 1;//计算材质球里总的pass数，如果没有则为1
        setting.matPassIndex = Mathf.Clamp(setting.matPassIndex, -1, passInt);//把设置里的pass的id限制在-1到材质的最大pass数
        myPass = new CustomRenderPass(setting.passEvent, setting.myMat,setting.matPassIndex, name);//实例化一下并传入参数，name为tag
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var src = renderer.cameraColorTarget;
        myPass.SetUp(src);
        renderer.EnqueuePass(myPass);
    }
}


