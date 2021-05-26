Shader "URP/URPRamp"
{
    Properties
    {
        _MainTex ("Ramp", 2D) = "white" {}
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
        float4 _MainTex_ST;
        half4 _BaseColor;
        CBUFFER_END

        sampler2D _MainTex;

        struct a2v
        {
            float4 positionOS:POSITION;
            float3 normalOS:NORMAL;
		};

        struct v2f
        {
            float4 positionCS:SV_POSITION;
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


            v2f vert (a2v i)
            {
                v2f o;
                o.positionCS =TransformObjectToHClip(i.positionOS.xyz);
                o.normalWS = normalize(TransformObjectToWorldNormal(i.normalOS));
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                half3 lightDir = normalize(GetMainLight().direction);
                float dott = dot(i.normalWS,lightDir)*0.5+0.5f;
                half4 tex = tex2D(_MainTex,float2(dott,0.5))*_BaseColor;
                return tex;
            }
            ENDHLSL
        }
    }
}
