Shader "URP/URPMainLightShadow"
{
    Properties
    {
        _MainTex ("MainTexture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _Gloss("Gloss",Range(10,300))=20
        _SpecularColor("Specular Color",Color)=(1,1,1,1)
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
        half _Gloss;
        half4 _SpecularColor;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v//这就是a2v 应用阶段传递模型给顶点着色器的数据
        {
            float4 positionOS : POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord : TEXCOORD;
        };

        struct v2f//这就是v2f 顶点着色器传递给片元着色器的数据
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord : TEXCOORD;
            float3 positionWS:TEXCOORD1;
            float3 normalWS:NORMAL;
        };

        ENDHLSL

        Pass
        {        
            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            //关键字编译多个变体shader 计算阴影所需要
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT//柔化阴影，得到软阴影

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);

                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(i.normalOS.xyz);

                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord)*_BaseColor;
                //TransformWorldToShadowCoord模型的世界空间顶点坐标输入，得到阴影坐标
                //GetMainLight（float4 shadowcoord），该函数是之前用的GetMainLight的重载形式
                //它会调用另外一个函数half MainLightRealtimeShadow(float4 shadowCoord)
                //该函数是专门用来计算阴影衰减的，使用它时，需声明关键字

                //计算带阴影衰减的主光源
                Light myLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                float3 WS_L = normalize(myLight.direction);
                float3 WS_N = normalize(i.normalWS);
                float3 WS_V = normalize(_WorldSpaceCameraPos-i.positionWS);
                float3 WS_H = normalize(WS_V+WS_L);

                //半兰伯特
                mainTex*=(dot(WS_L,WS_N)*0.5+0.5)*myLight.shadowAttenuation*half4(myLight.color,1);

                //高光
                float4 specular = pow(max(dot(WS_N,WS_H),0),_Gloss)*_SpecularColor*myLight.shadowAttenuation;

                return mainTex+specular;
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
