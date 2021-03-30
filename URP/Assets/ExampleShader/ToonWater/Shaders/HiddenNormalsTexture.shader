Shader "Hidden/Roystan/Normals Texture"
{
    Properties
    {
    }
    SubShader
    {
        Tags 
		{ 
            "RenderPipeline"="UniversalPipeline"
			"RenderType" = "Opaque"
		}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _BaseColor;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v
        {
            float4 positionOS : POSITION;
			float3 normalOS : NORMAL;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float3 normalWS : NORMAL;
        };
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert (a2v i)
            {
                v2f o;

                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.normalWS = normalize(TransformObjectToWorldNormal(i.normalOS.xyz));
                
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                return float4(i.normalWS, 0);
            }
            ENDHLSL
        }
    }
}
