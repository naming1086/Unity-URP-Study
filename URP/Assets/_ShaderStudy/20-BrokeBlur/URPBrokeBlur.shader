Shader "URP/Post/URPBrokeBlur"
{
    Properties
    {
       [HideInInspector]_MainTex ("MainTexture", 2D) = "white" {}
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Transparent"
        }
        Cull Off ZWrite Off ZTest Always

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_TexelSize;
        CBUFFER_END

        half _NearDis;
        half _FarDis;
        float _BlurSmoothness;
        float _Loop;
        float _Radius;

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_SourceTex);
        SAMPLER(sampler_SourceTex);
        SAMPLER(_CameraDepthTexture);

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

            float4 frag(v2f i):SV_Target
            {
                float a = 2.3398;
                float2x2 rotate = float2x2(cos(a),-sin(a),sin(a),cos(a));
                float2 UVPos = float2(_Radius,0);
                float2 uv;
                float r;
                float4 texcoord = 0;               
                
                for(int t = 1;t<_Loop;t++)
                {
                    r = sqrt(t);
                    UVPos = mul(rotate,UVPos);
                    uv = i.texcoord + _MainTex_TexelSize.xy*UVPos*r;
                    texcoord += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv);
                }

                return texcoord/(_Loop-1);
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

            float4 frag(v2f i):SV_Target
            {
                float depth = Linear01Depth(tex2D(_CameraDepthTexture,i.texcoord).x,_ZBufferParams).x;
                float4 blur = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
                float4 sour = SAMPLE_TEXTURE2D(_SourceTex,sampler_SourceTex,i.texcoord);
                _NearDis *= _ProjectionParams.w;
                _FarDis *= _ProjectionParams.w;
                float dis = 1 - smoothstep(_NearDis,saturate(_NearDis+_BlurSmoothness),depth);//计算近处
                dis += smoothstep(_FarDis,saturate(_FarDis+_BlurSmoothness),depth);//计算远处
                
                float4 combine = lerp(sour,blur,dis);

                return combine;
            }

            ENDHLSL
        }
    }
}
