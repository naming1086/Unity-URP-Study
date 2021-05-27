Shader "URP/Post/URPPost"
{
    Properties
    {
        [HideInspector]_MainTex ("MainTexture", 2D) = "white" {}
        _Brightness("Brightness",Range(0,1))=1
        _Saturate("Saturate",Range(0,1))=1
        _Contranst("Constrat",Range(-1,2))=1
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
        float4 _MainTex_ST;//ST = Sampler Texture 采样器纹理
        float _Brightness;
        float _Saturate;
        float _Contranst;
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

        Pass
        {        
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);
                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);       
                
                float gray = 0.21*mainTex.x+0.72*mainTex.y+0.72*mainTex.z;//灰度图，即计算明度
                mainTex.xyz *= _Brightness;
                mainTex.xyz = lerp(float3(0.5,0.5,05),mainTex.xyz,_Saturate);//饱和度
                mainTex.xyz = lerp(float3(0.5,0.5,05),mainTex.xyz,_Contranst);//对比度

                return mainTex;
            }
            ENDHLSL  //ENDCG
        }
    }
}
