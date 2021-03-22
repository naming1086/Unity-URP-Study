using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class Scan : ScriptableRendererFeature
{
    [System.Serializable] public class MySetting//定义一个设置类
    {
        public Material material = null;
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingTransparents;
    }
    public MySetting setting = new MySetting();

    class CustomRenderPass : ScriptableRenderPass//自定义pass
    {
        public Material material = null;
        public RenderTargetIdentifier PassSource { get; set; }

        public void SetUp(RenderTargetIdentifier source) //接收render feather传的图
        {
            this.PassSource = source;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            int temp = Shader.PropertyToID("temp");
            CommandBuffer cmd = CommandBufferPool.Get("扫描特效");
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            Camera camera = renderingData.cameraData.camera;
            float height = camera.nearClipPlane * Mathf.Tan(Mathf.Deg2Rad * camera.fieldOfView * 0.5F);
            Vector3 up = camera.transform.up * height;
            Vector3 right = camera.transform.right * height * camera.aspect;
            Vector3 forward = camera.transform.forward * camera.nearClipPlane; ;
            Vector3 ButtomLeft = forward - right - up;
            float scale = ButtomLeft.magnitude / camera.nearClipPlane;
            ButtomLeft.Normalize();
            ButtomLeft *= scale;
            Vector3 ButtomRight = forward + right - up;
            ButtomRight.Normalize();
            ButtomRight *= scale;
            Vector3 TopRight = forward + right + up;
            TopRight.Normalize();
            TopRight *= scale;
            Vector3 TopLeft = forward - right + up;
            TopLeft.Normalize();
            TopLeft *= scale;
            Matrix4x4 MATRIX = new Matrix4x4();
            MATRIX.SetRow(0, ButtomLeft);
            MATRIX.SetRow(1, ButtomRight);
            MATRIX.SetRow(2, TopRight);
            MATRIX.SetRow(3, TopLeft);
            material.SetMatrix("Matrix", MATRIX);
            cmd.GetTemporaryRT(temp, desc);
            cmd.Blit(PassSource, temp, material);
            cmd.Blit(temp, PassSource);
            context.ExecuteCommandBuffer(cmd);
            cmd.ReleaseTemporaryRT(temp);
            CommandBufferPool.Release(cmd);
        }
    }

    CustomRenderPass m_ScriptablePass;

    public override void Create()//进行初始化
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.material = setting.material;
        m_ScriptablePass.renderPassEvent = setting.Event;
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.SetUp(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


