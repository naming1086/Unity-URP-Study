Shader "URP/URPUnlitShader"
{
    Properties
    {
        _MainTex ("Base Texture", 2D) = "white" {}
        _BaseColor("Base Color",Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque" 
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;//ST = Sampler Texture 采样器纹理
        half4 _BaseColor;
        CBUFFER_END

        struct a2v//这就是a2v 应用阶段传递模型给顶点着色器的数据
        {
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD;
        };

        struct v2f//这就是v2f 顶点着色器传递给片元着色器的数据
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD;
        };

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        ENDHLSL

        Pass
        {        
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v IN)
            {
                v2f OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv=TRANSFORM_TEX(IN.uv,_MainTex);
                return OUT;
            }

            float4 frag(v2f IN):SV_Target
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);                
                return mainTex * _BaseColor;
            }
            ENDHLSL  //ENDCG
        }
    }
}
