Shader "URP/Post/URPDoualBlur"
{
    Properties
    {
       [HideInInspector]_MainTex ("MainTexture", 2D) = "white" {}
        //_Blur("Blur",float)=3
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
        float4 _MainTex_ST;
        float _Blur;
        float4 _MainTex_TexelSize;
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
            float4 texcoord[4] : TEXCOORD;
        };
        ENDHLSL

        Pass//Down
        {
            NAME"Down"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord[2].xy=i.texcoord;
                o.texcoord[0].xy = i.texcoord+float2(1,1)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                o.texcoord[0].zw = i.texcoord+float2(-1,1)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                o.texcoord[1].xy = i.texcoord+float2(1,-1)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                o.texcoord[1].zw = i.texcoord+float2(-1,-1)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord[2].xy)*0.5;       
                
                for(int t = 0;t<2;t++)
                {
                    mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord[t].xy)*0.125;
                    mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord[t].zw)*0.125;
                }

                return mainTex;
            }

            ENDHLSL
        }

        Pass//up
        {        
            NAME"Up"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord[0].xy = i.texcoord+float2(1,1)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                o.texcoord[0].zw = i.texcoord+float2(-1,1)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                o.texcoord[1].xy = i.texcoord+float2(1,-1)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                o.texcoord[1].zw = i.texcoord+float2(-1,-1)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                o.texcoord[2].xy = i.texcoord+float2(0,2)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                o.texcoord[2].zw = i.texcoord+float2(0,-2)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                o.texcoord[3].xy = i.texcoord+float2(-2,0)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;
                o.texcoord[3].zw = i.texcoord+float2(2,0)*_MainTex_TexelSize.xy*(1+_Blur)*0.5;

                return o;
            }

            half4 frag(v2f i):SV_Target
            {
                half4 mainTex = 0;
                for(int t = 0;t<2;t++)
                {
                    mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord[t].xy)/6;
                    mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord[t].zw)/6;
                }

                for(int k = 2;k<4;k++)
                {
                    mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord[k].xy)/12;
                    mainTex += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord[k].zw)/12;
                }

                return mainTex;
            }

            ENDHLSL
        }
    }
}
