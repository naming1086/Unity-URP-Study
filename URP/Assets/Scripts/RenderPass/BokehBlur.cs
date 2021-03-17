using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class BokehBlur : ScriptableRendererFeature
{
    [System.Serializable] public class MySetting//定义一个设置类
    {
        public string name = "散景模糊";
        public Material myMat = null;
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingOpaques;

        [Tooltip("降采样，越大性能越好但质量越低"), Range(1, 7)] public int downSample = 2;
        [Tooltip("迭代次数,越大圆斑越大但采样点越分散"), Range(3, 500)] public int loop = 50;
        [Tooltip("采样半径，越大园斑越大但采样点越分散"), Range(0.1f, 10)] public float Radius = 1;
        [Tooltip("模糊过渡的平滑度"), Range(0, 0.5f)] public float BlurSmoothness = 0.1f;
        [Tooltip("近处模糊结束的距离")] public float NearDis = 5;
        [Tooltip("远处模糊结束的距离")] public float FarDis = 9;
    }

    public MySetting setting = new MySetting();

    class CustomRenderPass : ScriptableRenderPass//自定义pass
    {
        public Material passMat = null;
        public string name;
        public int loop;
        public float BlurSmoothness;
        public int downSample;
        public float NearDis;
        public float FarDis;
        public float Radius;
        public RenderTargetIdentifier PassSource;
        int width;
        int height;
        readonly static int BlurID = Shader.PropertyToID("blur");//申请之后就不在变化
        readonly static int SourceBakedID = Shader.PropertyToID("_SourceTex");

        public void SetUp(RenderTargetIdentifier source) //接收render feather传的图
        {
            this.PassSource = source;
            passMat.SetFloat("_Loop", loop);
            passMat.SetFloat("_Radius", Radius);
            passMat.SetFloat("_NearDis", NearDis);
            passMat.SetFloat("_FarDis", FarDis);
            passMat.SetFloat("_BlurSmoothness", BlurSmoothness);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(name);
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            width = desc.width / downSample;
            height = desc.height / downSample;
            cmd.GetTemporaryRT(BlurID, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);
            cmd.GetTemporaryRT(SourceBakedID, desc);
            cmd.CopyTexture(PassSource, SourceBakedID);//把相机图像复制到备份RT图，并自动发送到shader里，无需手动指定发送
            cmd.Blit(PassSource, BlurID, passMat, 0);//第一个pass，把屏幕图像计算后存到一个降采样的模糊图里
            cmd.Blit(BlurID, PassSource, passMat, 1);//第二个pass，发送模糊图到shader的maintex，然后混合输出

            context.ExecuteCommandBuffer(cmd);
            cmd.ReleaseTemporaryRT(BlurID);
            cmd.ReleaseTemporaryRT(SourceBakedID);
            CommandBufferPool.Release(cmd);
        }
    }

    CustomRenderPass m_ScriptablePass;

    public override void Create()//进行初始化
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.passMat = setting.myMat;
        m_ScriptablePass.loop = setting.loop;
        m_ScriptablePass.BlurSmoothness = setting.BlurSmoothness;
        m_ScriptablePass.Radius = setting.Radius;
        m_ScriptablePass.renderPassEvent = setting.passEvent;
        m_ScriptablePass.name = setting.name;
        m_ScriptablePass.downSample = setting.downSample;
        m_ScriptablePass.NearDis = Mathf.Max(setting.NearDis, 0);
        m_ScriptablePass.FarDis = Mathf.Max(setting.NearDis, setting.FarDis);
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
            Debug.LogError("散景模糊材质球丢失");
        }
    }
}


