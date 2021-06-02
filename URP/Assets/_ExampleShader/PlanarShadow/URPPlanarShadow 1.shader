Shader "URP/URPPlanarShadowNoShadow"
{
    Properties
    {
        _MainTex("Main Tex", 2D) = "white" { }
        _BaseColor("Base Color",Color) = (1,1,1,1)

        [Header(Shadow)]
        _GroundHeight("_GroundHeight", Float) = 0
        _ShadowColor("_ShadowColor", Color) = (0, 0, 0, 1)
        _ShadowFalloff("_ShadowFalloff", Range(0, 1)) = 0.05
    }
    SubShader
    {
        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        half _GroundHeight;
        half4 _ShadowColor;
        half _ShadowFalloff;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        ENDHLSL

        //MainColor Pass
        Pass
        {
            NAME"MainPass"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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

            v2f vert(a2v v)
            {
                v2f o;
                //在齐次裁剪空间中的坐标
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            };

            half4 frag(v2f i) : SV_TARGET
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _BaseColor;

                return mainTex;
            };
            ENDHLSL
        }
    }
}
