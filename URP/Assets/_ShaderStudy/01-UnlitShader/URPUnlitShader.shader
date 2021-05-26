Shader "URP/URPUnlitShader"
{
    Properties
    {
        _MainTex ("Base Texture", 2D) = "white" {} 
        _BaseColor("Base Color",Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque" 
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        //CBUFFER(常量缓冲区)的空间较小,不适合存放纹理贴图这种大量数据的数据类型，适合存放float，half之类的不占空间的数据
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;//ST = Sampler Texture 采样器纹理
        half4 _BaseColor;
        CBUFFER_END

        struct a2v//这就是a2v 应用阶段传递模型给顶点着色器的数据
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD;
        };

        struct v2f//这就是v2f 顶点着色器传递给片元着色器的数据
        {
            float4 positionCS : SV_POSITION;//必须
            float2 texcoord : TEXCOORD;
        };

        //新的DXD11 HLSL贴图的采样函数和采样器函数，TEXTURE2D (_MainTex)和SAMPLER(sampler_MainTex)，用来定义采样贴图和采样状态代替原来DXD9的sampler2D
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

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
                // 贴图的采用输出函数采用DXD11 HLSL下的 SAMPLE_TEXTURE2D(textureName, samplerName, coord2) ，
                // 具有三个变量，分别是TEXTURE2D (_MainTex)的变量和SAMPLER(sampler_MainTex)的变量和uv，
                // 用来代替原本DXD9的TEX2D(_MainTex,texcoord)。

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);                
                return mainTex * _BaseColor;
            }
            ENDHLSL  //ENDCG
        }
    }
}
