Shader "URP/Post/URPKawaseBlur"
{
    Properties
    {
        _MainTex ("MainTexture", 2D) = "white" {}
        //_Blur("Blur",float)=2
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
        }
        Cull Off ZWrite Off ZTest Always

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_TexelSize;
        CBUFFER_END

        float _Blur;

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

        v2f vert(a2v i)//水平方向的采样
        {
            v2f o;
            o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
            o.texcoord=i.texcoord;
            return o;
        }

        float4 frag(v2f i):SV_Target
        {
            half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);       
                
            mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+float2(-1,-1)*_MainTex_TexelSize.xy*_Blur);
            mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+float2(1,-1)*_MainTex_TexelSize.xy*_Blur);
            mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+float2(-1,1)*_MainTex_TexelSize.xy*_Blur);
            mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+float2(1,1)*_MainTex_TexelSize.xy*_Blur);

            return mainTex/5.0;
        }
        ENDHLSL

        Pass
        {        
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}
