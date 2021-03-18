Shader "URP/Post/URPScan"
{
    Properties
    {
       [HideInInspector]_MainTex ("MainTexture", 2D) = "white" {}
       [HDR]_ColorX("ColorX",Color)=(1,1,1,1)
       [HDR]_ColorY("ColorY",Color)=(1,1,1,1)
       [HDR]_ColorZ("ColorZ",Color)=(1,1,1,1)
       [HDR]_ColorEdge("ColorEdge",Color)=(1,1,1,1)
       _Width("Width",float)=0.02
       _Spacing("Spacing",float)=1
       _Speed("Speed",float)=1
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

        half4 _ColorX;
        half4 _ColorY;
        half4 _ColorZ;
        half4 _ColorEdge;
        float _Width;
        float _Spacing;
        float _Speed;

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);

        float4x4 Matrix;

        struct a2v
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord : TEXCOORD;
            float3 dirction : TEXCOORD1;
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

                int t = 0;
                if(i.texcoord.x<0.5&&i.texcoord.y<0.5)
                    t = 0;
                else if(i.texcoord.x>0.5&&i.texcoord.y<0.5)
                    t = 1;
                else if(i.texcoord.x>0.5&&i.texcoord.y>0.5)
                    t = 2;
                else
                    t = 3;

                o.dirction = Matrix[t].xyz;

                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                float4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
                half depth = Linear01Depth(SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,i.texcoord).x,_ZBufferParams).x;

                float3 WSPos = _WorldSpaceCameraPos + depth*i.dirction+float3(0.1,0.1,0.1);//得到世界坐标
                return 
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
