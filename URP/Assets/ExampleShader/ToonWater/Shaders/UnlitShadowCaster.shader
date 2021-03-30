Shader "Roystan/Unlit/Shadow Caster"
{
    Properties
    {
		_BaseColor("BaseColor", Color) = (1,1,1,1)
        _MainTex ("MainTex", 2D) = "white" {}
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
            float2 texcoord : TEXCOORD;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord : TEXCOORD;
        };
        ENDHLSL
		//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert (a2v i)
            {
                v2f o;

                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
                return mainTex * _BaseColor;
            }
            ENDHLSL
        }
    }
}
