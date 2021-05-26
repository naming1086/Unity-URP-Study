Shader "URP/URPGrass"
{
    Properties
    {
        _NormalTex("Normal",2D)="bump"{}
        _NormalScale("NormalScale",Range(0,1))=1
        _BaseColor("Base Color",Color)=(1,1,1,1)
        _Amount("amount",float) = 100
        [KeywordEnum(WS_N,TS_N)]_NORMAL_STAGE("NormalStage",float)=1
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _NormalTex_ST;//ST = Sampler Texture 采样器纹理
        half4 _BaseColor;
        float _NormalScale;
        float _Amount;
        CBUFFER_END

        float4 _CameraColorTexture_TexelSize;//该向量是非本shader独有，不能放在常量缓冲区

        TEXTURE2D(_NormalTex);
        SAMPLER(sampler_NormalTex);
        SAMPLER(_CameraColorTexture);

        struct a2v
        {
            float4 positionOS : POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord : TEXCOORD;
            float4 tangentOS:TANGENT;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;//必须
            float2 texcoord : TEXCOORD;
            float4 normalWS:NORMAL;
            float4 tangentWS:TANGENT;
            float4 bitangentWS:TEXCOORD1;
        };

        ENDHLSL

        Pass
        {        
            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local _NORMAL_STAGE_WS_N

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_NormalTex);

                o.normalWS.xyz = normalize(TransformObjectToWorldNormal(i.normalOS.xyz));
                o.tangentWS.xyz = normalize(TransformObjectToWorldDir(i.tangentOS.xyz));
                o.bitangentWS.xyz = cross(o.normalWS.xyz,o.tangentWS.xyz)*i.tangentOS.w*unity_WorldTransformParams.w;

                float3 positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.normalWS.w = positionWS.x;
                o.tangentWS.w = positionWS.y;
                o.bitangentWS.w = positionWS.z;

                return o;
            }

            half4 frag(v2f i):SV_Target
            {
                //获取法线贴图
                half4 normalTex = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.texcoord)*_BaseColor;          
                
                //得到我们想要对比的切线空间法线
                float3 normalTS = UnpackNormalScale(normalTex,_NormalScale);

                //获取屏幕uv
                float2 SS_Texcoord = i.positionCS.xy/_ScreenParams.xy;

                #ifdef _NORMAL_STAGE_WS_N//计算偏移的2张方式
                //构建tbn矩阵
                float3x3 matrix_T2W = {i.tangentWS.xyz,i.bitangentWS.xyz,i.normalWS.xyz};
                
                //得到我们想要的世界空间法线
                float3 WS_Normal = mul(normalTS,matrix_T2W);

                //如果取的世界空间的法线则执行它计算偏移，但是世界空间的法线由世界空间确定，会随着模型的旋转而变化；
                float2 SS_Bias = WS_Normal.xy*_Amount*_CameraColorTexture_TexelSize.xy;

                #else
                //如果取的是切线空间的法线则执行它计算偏移，但是切线空间的法线不随着模型的旋转而变换；
                float2 SS_Bias = normalTS.xy*_Amount*_CameraColorTexture_TexelSize.xy;
                #endif
                //把最终的颜色输出到屏幕即可
                float4 glassColor = tex2D(_CameraColorTexture,SS_Texcoord+SS_Bias);

                return real4(glassColor.xyz,1);
            }
            ENDHLSL  //ENDCG
        }
    }
}
