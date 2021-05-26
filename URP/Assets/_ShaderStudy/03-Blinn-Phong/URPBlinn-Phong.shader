Shader "URP/URPBlinn-Phong"
{
    Properties
    {
        _MainTex ("Base Texture", 2D) = "white" {}
        _BaseColor("Base Color",Color)=(1,1,1,1)
        _SpecularRange("SpecularRange",Range(10,300))=10
        _SpecularColor("SpecularColor",Color)=(1,1,1,1)
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
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;//ST = Sampler Texture 采样器纹理
        half4 _BaseColor;
        float _SpecularRange;
        float4 _SpecularColor;
        CBUFFER_END

        struct a2v//这就是a2v 应用阶段传递模型给顶点着色器的数据
        {
            float4 positionOS : POSITION;
            float4 normalOS:NORMAL;
            float2 uv : TEXCOORD0;
        };

        struct v2f//这就是v2f 顶点着色器传递给片元着色器的数据
        {
            float4 positionCS : SV_POSITION;
            float3 normalWS : NORMAL;
            float3 viewDirWS : TEXCOORD;
            float2 uv : TEXCOORD1;
        };

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        ENDHLSL

        Pass
        {        
            NAME"MainPass"

            Tags{
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v IN)
            {
                v2f OUT;
                //在齐次裁剪空间中的坐标
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                //在世界空间中的法线
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS.xyz);
                //得到世界空间的视图方向
                OUT.viewDirWS = normalize(_WorldSpaceCameraPos.xyz-TransformObjectToWorld(IN.positionOS.xyz));

                OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);

                return OUT;
            }

            float4 frag(v2f IN):SV_Target
            {
                //half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv)*_BaseColor; 

                Light mylight = GetMainLight();

                //光线方向
                float3 LightDirWS = normalize(mylight.direction);

                float spe = dot(normalize(LightDirWS+IN.viewDirWS),IN.normalWS);

                half4 speColor = pow(spe,_SpecularRange)*_SpecularColor;
                half4 texColor = (dot(IN.normalWS,LightDirWS)*0.5+0.5)*SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv)*_BaseColor;

                texColor*=half4(mylight.color,1);

                return speColor+texColor;

            }
            ENDHLSL  //ENDCG
        }
    }
}
