using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class URPScanPlus : ScriptableRendererFeature
{
    public enum Axis
    {
        X,
        Y,
        Z
    }

    [System.Serializable] public class MySetting//定义一个设置类
    {
        public Material material = null;
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingTransparents;
        [ColorUsage(true,true)]public Color ColorX = Color.white;
        [ColorUsage(true,true)]public Color ColorY = Color.white;
        [ColorUsage(true,true)]public Color ColorZ = Color.white;
        [ColorUsage(true,true)]public Color ColorEdge = Color.white;
        [ColorUsage(true,true)]public Color ColorOutline = Color.white;
        [Range(0, 0.2f), Tooltip("linebox width")] public float Width = 0.1f;
        [Range(0.1f, 10), Tooltip("线框间距")] public float Spacing = 1;
        [Range(0, 10), Tooltip("滚动速度")] public float Speed = 1;
        [Range(0, 3), Tooltip("边缘取样尺寸")] public float EdgeSample = 1;
        [Range(0, 3), Tooltip("法线灵敏度")] public float NormalSensitivity = 1;
        [Range(0, 3), Tooltip("深度灵敏度")] public float DepthSensitivity = 1;

        [Tooltip("特效方向")] public Axis axis;
    }
    public MySetting setting = new MySetting();

    class CustomRenderPass : ScriptableRenderPass//自定义pass
    {
        public Material material = null;
        public RenderTargetIdentifier PassSource { get; set; }

        public Color ColorX = Color.white;
        public Color ColorY = Color.white;
        public Color ColorZ = Color.white;
        public Color ColorEdge = Color.white;
        public Color ColorOutline = Color.white;
        public float Width = 0.05f;
        public float Spacing = 2;
        public float Speed = 0.7f;
        public float EdgeSample = 1;
        public float NormalSensitivity = 1;
        public float DepthSensitivity = 1;
        public Axis axis;

        public void SetUp(RenderTargetIdentifier source)
        {
            this.PassSource = source;
            material.SetColor("_ColorX", ColorX);
            material.SetColor("_ColorY", ColorX);
            material.SetColor("_ColorZ", ColorX);
            material.SetColor("_ColorEdge", ColorX);
            material.SetColor("_ColorColor", ColorX);
            material.SetFloat("_Width", Width);
            material.SetFloat("_Spacing", Spacing);
            material.SetFloat("_EdgeSample", EdgeSample);
            material.SetFloat("_NormalSensitivity", NormalSensitivity);
            material.SetFloat("_DepthSensitivity", DepthSensitivity);
            if(axis == Axis.X)
            {
                material.DisableKeyword("_AXIS_Y");
                material.DisableKeyword("_AXIS_Z");
                material.EnableKeyword("_AXIS_X");
            }
            else if(axis == Axis.Y)
            {
                material.DisableKeyword("_AXIS_X");
                material.DisableKeyword("_AXIS_Z");
                material.EnableKeyword("_AXIS_Y");
            }
            else
            {
                material.DisableKeyword("_AXIS_X");
                material.DisableKeyword("_AXIS_Y");
                material.EnableKeyword("_AXIS_Z");
            }
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
        m_ScriptablePass.ColorX = setting.ColorX;
        m_ScriptablePass.ColorY = setting.ColorY;
        m_ScriptablePass.ColorZ = setting.ColorZ;
        m_ScriptablePass.ColorEdge = setting.ColorEdge;
        m_ScriptablePass.ColorOutline = setting.ColorOutline;
        m_ScriptablePass.Width = setting.Width;
        m_ScriptablePass.Spacing = setting.Spacing;
        m_ScriptablePass.Speed = setting.Speed;
        m_ScriptablePass.EdgeSample = setting.EdgeSample;
        m_ScriptablePass.NormalSensitivity = setting.NormalSensitivity;
        m_ScriptablePass.DepthSensitivity = setting.DepthSensitivity;
        m_ScriptablePass.axis = setting.axis;
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.SetUp(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


