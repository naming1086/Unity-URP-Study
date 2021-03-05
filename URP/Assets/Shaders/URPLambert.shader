Shader "URP/URPLambert"
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
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;//ST = Sampler Texture 采样器纹理
        half4 _BaseColor;
        CBUFFER_END

        struct a2v//这就是a2v 应用阶段传递模型给顶点着色器的数据
        {
            float4 positionOS : POSITION;
            float4 normalOS:NORMAL;
            float2 uv : TEXCOORD;
        };

        struct v2f//这就是v2f 顶点着色器传递给片元着色器的数据
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD;
            float3 normalWS : TEXCOORD1;
        };

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        ENDHLSL

        Pass
        {        
            Tags{
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v IN)
            {
                v2f OUT;
                //在齐次裁剪空间中的坐标
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv=TRANSFORM_TEX(IN.uv,_MainTex);
                //在世界空间中的法线
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS.xyz);

                return OUT;
            }

            float4 frag(v2f IN):SV_Target
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv)*_BaseColor; 

                Light mylight = GetMainLight();
                half4 LightColor = half4(mylight.color,1);

                //光线方向
                float3 LightDir = normalize(mylight.direction);

                //光线和世界坐标法线的点积，需要在同一坐标系，点积才有意义
                float LightAten = dot(LightDir,IN.normalWS);

                return mainTex * LightAten*LightColor;
                //return mainTex*LightAten*LightColor*0.5+0.5;//半兰伯特光照模型
            }
            ENDHLSL  //ENDCG
        }
    }
}
