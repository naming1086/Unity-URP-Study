Shader "MyURP/Dissolution"
{
    Properties
    {
        _MainTex("MainTex",2D) = "white"{}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _CellWidth("CellWidth",Range(-1,1))=0.5
        _CellColor("CellColor",Color)=(1,1,1,1)
        _HighLightWidth("HighLightWidth",Range(-1,1))=0.5
        _HighLightColor("HighLightColor",Color) = (1,1,1,1)
        _DissolutionTex("DissolutionTex",2D) = "white"{}
        _AlphaCutoff("AlphaCutoff",Range(0,1)) = 0.5
        _DissolutionWidth("DissolutionWidth",float) = 0.2
        _EmissionsIntensity("EmissionsIntensity",float) =1.0
        _EmissionsColor("EmissionsColor",Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags 
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType" = "TransparentCutout"
            "Queue" = "Geometry"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        CBUFFER_START(UnityPerMaterial)

        float4 _MainTex_ST;
        float4 _DissolutionTex_ST;
        float4 _BaseColor;

        float _CellWidth;
        float4 _CellColor;

        float _HighLightWidth;
        float4 _HighLightColor;

        float _AlphaCutoff;
        float _DissolutionWidth;
        float _EmissionsIntensity;
        float4 _EmissionsColor;

        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_DissolutionTex);
        SAMPLER(sampler_DissolutionTex);

        struct a2v
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD;
            float3 normalOS : NORMAL;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord : TEXCOORD0;
            float3 viewDir : TEXCOORD1;
            float3 normalWS : TEXCOORD2;
            float2 texcoord2 : TEXCOORD3;
        };
        ENDHLSL

        Pass
        {
            Name "BASE"
            Tags 
            {
                "LightMode" = "LightweightForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma target 3.0

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(i.normalOS);

                o.texcoord = TRANSFORM_TEX(i.texcoord,_MainTex);
                o.texcoord2 = TRANSFORM_TEX(i.texcoord,_DissolutionTex);

                o.viewDir = normalize(_WorldSpaceCameraPos.xyz-TransformObjectToWorld(i.positionOS.xyz));
                return o;
            }

            half4 frag(v2f i):SV_Target
            {
                Light mainLight = GetMainLight();
                half LdotN = dot(mainLight.direction,i.normalWS);
                LdotN = saturate(step(0,LdotN-_CellWidth));                
                ///
                half3 halfAngle = normalize(normalize(mainLight.direction)+normalize(i.viewDir));
                half HdotN = saturate(dot(halfAngle,i.normalWS));
                HdotN = saturate(ceil(HdotN-_HighLightWidth));
                ///
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
                half4 dissolutionTex = SAMPLE_TEXTURE2D(_DissolutionTex,sampler_DissolutionTex,i.texcoord2);
                ///
                half4 baseColor = lerp(_CellColor,_BaseColor,LdotN)*mainTex;
                half4 finalColor= lerp(baseColor,_HighLightColor+mainTex,HdotN);
                                ///
                half em1 = step(0,dissolutionTex.r - _AlphaCutoff+_DissolutionWidth);
                half em2 = step(0,dissolutionTex.r - _AlphaCutoff-_DissolutionWidth);
                half em = em1 - em2;
                half4 emissions = em*_EmissionsIntensity*_EmissionsColor;
                ///
                clip(dissolutionTex.r - _AlphaCutoff);
                return finalColor+emissions;
            }
        ENDHLSL
        }
    }
}
