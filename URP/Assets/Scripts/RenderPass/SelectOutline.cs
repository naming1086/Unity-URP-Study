using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class SelectOutline : ScriptableRendererFeature
{
    public enum TYPE
    {
        INColorON,INColorOFF
    }

    [System.Serializable] public class MySetting//定义一个设置类
    {
        public Material material = null;
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingSkybox;
        public Color color = Color.blue;
        [Range(1000, 5000)] public int QueueMin = 2000;
        [Range(1000, 5000)] public int QUeueMax = 2500;
        public LayerMask layer;
        [Range(0.0f, 3.0f)] public float blur = 1.0f;
        [Range(1, 5)] public int passLoop = 3;
        public TYPE ColorType = TYPE.INColorON;
    }
    public MySetting setting = new MySetting();
    int solidColorID;
    
    //第一个pass绘制纯色的图像
    class DrawSoildColorPass : ScriptableRenderPass
    {
        MySetting setting = null;
        SelectOutline selectOutline = null;
        ShaderTagId shaderTagId = new ShaderTagId("DepthOnly");//只有在这个标签LightMode对应的Shader才会被绘制
        FilteringSettings filter;
        public DrawSoildColorPass(MySetting setting,SelectOutline selectOutline)
        {
            this.setting = setting;
            this.selectOutline = selectOutline;
            //过滤设定
            RenderQueueRange queue = new RenderQueueRange();
            queue.lowerBound = Mathf.Min(setting.QUeueMax, setting.QueueMin);
            queue.upperBound = Mathf.Max(setting.QUeueMax, setting.QueueMin);
            filter = new FilteringSettings(queue, setting.layer);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            int temp = Shader.PropertyToID("_MyTempColor1");
            RenderTextureDescriptor desc = cameraTextureDescriptor;
            cmd.GetTemporaryRT(temp, desc);
            selectOutline.solidColorID = temp;
            ConfigureTarget(temp);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            setting.material.SetColor("_SoildColor", setting.color);
            CommandBuffer cmd = CommandBufferPool.Get("提取固有色pass");
            //绘制设定
            var draw = CreateDrawingSettings(shaderTagId, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);
            draw.overrideMaterial = setting.material;
            draw.overrideMaterialPassIndex = 0;
            //开始绘制（准备好了绘制设定和过滤设定）
            context.DrawRenderers(renderingData.cullResults, ref draw, ref filter);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    //第二个pass 计算颜色
    class Calculate : ScriptableRenderPass
    {
        MySetting setting = null;
        SelectOutline selectOutline = null;
        struct LEVEL
        {
            public int down;
            public int up;
        };
        LEVEL[] levels;
        int maxLevel = 16;
        RenderTargetIdentifier sour;
        public Calculate(MySetting setting,SelectOutline render,RenderTargetIdentifier source)
        {
            this.setting = setting;
            selectOutline = render;
            sour = source;
            levels = new LEVEL[maxLevel];
            for (int t = 0; t < maxLevel; t++)//申请32个ID的，up和down各16个，用这个id去代替临时RT来使用
            {
                levels[t] = new LEVEL
                {
                    down = Shader.PropertyToID("_BlurMipDown" + t),
                    up = Shader.PropertyToID("_BlurMipUp" + t)
                };
            }

            if(setting.ColorType == TYPE.INColorON)
            {
                setting.material.EnableKeyword("_INCOLORON");
                setting.material.DisableKeyword("_INCOLOROFF");
            }
            else
            {
                setting.material.EnableKeyword("_INCOLOROFF");
                setting.material.DisableKeyword("_INCOLORON");
            }
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("颜色计算");
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;

            int SourID = Shader.PropertyToID("_SourTex");
            cmd.GetTemporaryRT(SourID, desc);
            cmd.CopyTexture(sour, SourID);

            //计算双重kawase模糊
            int BlurID = Shader.PropertyToID("_BlurTex");
            cmd.GetTemporaryRT(BlurID, desc);
            setting.material.SetFloat("_Blur", setting.blur);
            int width = desc.width / 2;
            int height = desc.height / 2;

            //down
            int lastDown = selectOutline.solidColorID;
            for (int t = 0; t < setting.passLoop; t++)
            {
                int midDown = levels[t].down;//middle down，即间接计算down的工具ID
                int midUp = levels[t].up;//middle up，即间接计算up的工具ID

                //对指定高度申请RT，每个循环的指定RT都会变小为原来的一半
                cmd.GetTemporaryRT(midDown, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);
                //同上，但是这里申请了并未计算，先把位置霸占了，这样在UP的循环里就不用申请RT了
                cmd.GetTemporaryRT(midUp, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);

                cmd.Blit(lastDown, midDown, setting.material, 1);//计算down的pass
                lastDown = midDown;
                width = Mathf.Max(width / 2, 1);
                height = Mathf.Max(height / 2, 1);
            }

            //up
            int lastUp = levels[setting.passLoop - 1].down;//把down的最后一次图像当成up的第一张图去计算up
            for (int j = setting.passLoop - 2; j >= 0 ; j--)//这里减2是因为第一次已经有了要减去1，但是第一次是直接复制的，所以循环完后还得补一次up
            {
                int midUp = levels[j].up;
                cmd.Blit(lastUp, midUp, setting.material, 2);
                lastUp = midUp;
            }

            cmd.Blit(lastUp, BlurID, setting.material, 2);//补应该up，再模糊一下
            cmd.Blit(selectOutline.solidColorID, sour, setting.material, 3);//在第四个pass里合拼所有图像
            context.ExecuteCommandBuffer(cmd);

            //回收
            for (int t = 0; t < setting.passLoop; t++)
            {
                cmd.ReleaseTemporaryRT(levels[t].up);
                cmd.ReleaseTemporaryRT(levels[t].down);
            }
            cmd.ReleaseTemporaryRT(BlurID);
            cmd.ReleaseTemporaryRT(SourID);
            cmd.ReleaseTemporaryRT(selectOutline.solidColorID);
            CommandBufferPool.Release(cmd);
        }
    }

    DrawSoildColorPass m_DrawSoildColorPass;
    Calculate m_Calculate;

    public override void Create()//进行初始化
    {
        m_DrawSoildColorPass = new DrawSoildColorPass(setting, this);
        m_DrawSoildColorPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(setting.material != null)
        {
            RenderTargetIdentifier sour = renderer.cameraColorTarget;
            renderer.EnqueuePass(m_DrawSoildColorPass);
            m_Calculate = new Calculate(setting, this, sour);
            m_Calculate.renderPassEvent = setting.Event;
            renderer.EnqueuePass(m_Calculate);
        }
        else
        {
            Debug.LogError("材质球丢失！请设置材质球");
        }
    }
}


