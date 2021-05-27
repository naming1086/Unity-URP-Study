Shader "URP/Post/URPRadialBlur"
{
    Properties
    {
        _MainTex ("MainTexture", 2D) = "white" {}
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

        float4 _MainTex_ST;
        float _Loop;
        float _Blur;
        float _X;
        float _Y;
        float _Instensity;

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_SourceTex);
        SAMPLER(sampler_SourceTex);

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

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord = i.texcoord;
                return o;
            }

            half4 frag(v2f i):SV_Target
            {
                float4 mainTex = 0;
                float2 dir = (i.texcoord - float2(_X,_Y))*_Blur*0.01;
                for(int t = 0;t<_Loop;t++)
                {
                    mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+dir*t)/_Loop;
                }
                return mainTex;
            }
            ENDHLSL
        }

        Pass
        {        
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord = i.texcoord;
                return o;
            }

            half4 frag(v2f i):SV_Target
            {
                float4 blur = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);//得到模糊贴图
                float4 source = SAMPLE_TEXTURE2D(_SourceTex,sampler_SourceTex,i.texcoord);//得到屏幕原始图

                return lerp(source,blur,_Instensity);
            }

            ENDHLSL
        }
    }
}
