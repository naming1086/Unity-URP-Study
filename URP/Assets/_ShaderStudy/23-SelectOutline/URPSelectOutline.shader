Shader "URP/Post/URPSelectOutline"
{
    Properties
    {
       [HideInInspector]_MainTex ("MainTexture", 2D) = "white" {}
       [HideInInspector]_SoildColor("SoildColor",Color)=(1,1,1,1)
       [HideInInspector]_Blur("Blur",float)=1

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
        float4 _SoildColor;
        float _Blur;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_SourTex);
        SAMPLER(sampler_SourTex);
        TEXTURE2D(_BlurTex);
        SAMPLER(sampler_BlurTex);
        float4x4 Matrix;

        struct a2v
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float4 texcoord[4]:TEXCOORD;
        };
        ENDHLSL

        Pass//上纯色
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                return _SoildColor;
            }
            ENDHLSL
        }

        Pass//双重模糊DownPass
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

        Pass//双重模糊UpPass
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

        Pass//合并所有图像
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local _INCOLORON _INCOLOROFF

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord[0].xy = i.texcoord.xy;
                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                float4 blur = SAMPLE_TEXTURE2D(_BlurTex,sampler_BlurTex,i.texcoord[0].xy); 
                float4 sour = SAMPLE_TEXTURE2D(_SourTex,sampler_SourTex,i.texcoord[0].xy); 
                float4 soild = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord[0].xy); 

                float4 color;
                #ifdef _INCOLORON
                color = abs(blur - soild)+sour;
                #elif _INCOLOROFF
                color = saturate(blur - soild)+sour;
                #endif
                return color;
            }
            ENDHLSL
        }
    }
}
