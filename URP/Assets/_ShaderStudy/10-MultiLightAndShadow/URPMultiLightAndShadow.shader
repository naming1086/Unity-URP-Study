Shader "URP/URPMultiLightAndShadow"
{
    Properties
    {
        _MainTex ("MainTexture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        [KeywordEnum(ON,OFF)]_ADD_LIGHT("AddLight",float)=1
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
            float3 WS_N:NORMAL;
            float3 WS_P:TEXCOORD1;
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
            #pragma shader_feature _ADD_LIGHT_ON _ADD_LIGHT_OFF


            //关键字编译多个变体shader 计算阴影所需要
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT//柔化阴影，得到软阴影

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);
                
                o.WS_N = normalize(TransformObjectToWorldNormal(i.normalOS.xyz));
                o.WS_P = TransformObjectToWorld(i.positionOS.xyz);

                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord)*_BaseColor;
                //计算带阴影衰减的主光源
                Light myLight = GetMainLight(TransformWorldToShadowCoord(i.WS_P));
                float3 WS_Light = normalize(myLight.direction);
                float3 WS_Normal = i.WS_N;
                float3 WS_Pos = i.WS_P;

                //计算主光源         
                float4 mainColor =(dot(WS_Light,WS_Normal)*0.5+0.5)*myLight.shadowAttenuation*half4(myLight.color,1)*mainTex;

                //计算叠加光源
                half4 addColor = half4(0,0,0,1);
                #if _ADD_LIGHT_ON
                int addLightCount = GetAdditionalLightsCount();
                for(int i = 0;i<addLightCount;i++)
                {
                    Light addLight = GetAdditionalLight(i,WS_Pos);
                    float3 WS_AddLightDir = normalize(addLight.direction);
                    addColor+=(dot(WS_AddLightDir,WS_Normal)*0.5+0.5)*addLight.shadowAttenuation*addLight.distanceAttenuation*half4(addLight.color,1)*mainTex;
                }
                #else
                addColor = half4(0,0,0,1);
                #endif
                return mainColor+addColor;
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
