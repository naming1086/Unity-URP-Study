Shader "URP/URPAlphaBlend"
{
    Properties
    {
        _MainTex ("Main Tex", 2D) = "white" {}
        _BaseColor("Base Color",Color)=(1,1,1,1)
        _AlphaTex("Alpha Tex",2D)="white"{}
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "IgonreProjector"="True"
            "RenderType"="Opaque" 
            "Queue"="Transparent"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        float4 _AlphaTex_ST;
        CBUFFER_END

        //声明纹理
        TEXTURE2D(_MainTex);
        //声明采样器
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_AlphaTex);
        SAMPLER(sampler_AlphaTex);

        struct a2v
        {
            float4 positionOS:POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord:TEXCOORD;
		};

        struct v2f
        {
            float4 positionCS:SV_POSITION;
            float4 texcoord:TEXCOORD;
		};
        ENDHLSL


        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert (a2v i)
            {
                v2f o;
                o.positionCS=TransformObjectToHClip(i.positionOS.xyz);
                //对纹理坐标进行偏移和缩放
                o.texcoord.xy=TRANSFORM_TEX(i.texcoord,_MainTex);
                o.texcoord.zw=TRANSFORM_TEX(i.texcoord,_AlphaTex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                //对纹理进行采样，传入参数（纹理，纹理采样器，纹理坐标）
                half4 tex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord.xy)*_BaseColor;
                float alpha = SAMPLE_TEXTURE2D(_AlphaTex,sampler_AlphaTex,i.texcoord.zw).x;
                return half4(tex.xyz,alpha);
            }
            ENDHLSL
        }
    }
}
