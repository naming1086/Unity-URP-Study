Shader "URP/ColorGradation"
{
    Properties
    {
        [PerRendererData] _MainTex("Sprite Texture", 2D) = "white" {}
        _SwapTex("Color Data", 2D) = "transparent" {}
        _Color("Tint", Color) = (1,1,1,1)
        [MaterialToggle] PixelSnap("Pixel snap", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }
            
        Lighting Off
        Blend SrcAlpha OneMinusSrcAlpha

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _SwapTex_ST;
        half4 _Color;
        half _Hue;
        float PixelSnap;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_SwapTex);
        SAMPLER(sampler_SwapTex);

        struct a2v
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord : TEXCOORD0;
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
                o.texcoord = TRANSFORM_TEX(i.texcoord, _MainTex);
                return o;
            }

            //half4 SampleSpriteTexture(float2 uv)
            //{
            //    fixed4 color = tex2D(_MainTex, uv);
            //    if (_AlphaSplitEnabled)
            //    color.a = tex2D(_AlphaTex, uv).r;

            //    return color;
            //}

            half4 frag (v2f i) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
                half4 swapCol = SAMPLE_TEXTURE2D(_SwapTex,sampler_MainTex, float2(col.r, 0));
                half4 final = lerp(col, swapCol, swapCol.a)*_Color;
                final.a = col.a;
                final.rgb *= col.a;
                return final;
            }

            ENDHLSL
        }
    }
}
