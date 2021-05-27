Shader "URP/Post/URPScanPlus"
{
    Properties
    {
       [HideInInspector]_MainTex ("MainTexture", 2D) = "white" {}
       [HideInInspector][HDR]_ColorX("ColorX",Color)=(1,1,1,1)
       [HideInInspector][HDR]_ColorY("ColorY",Color)=(1,1,1,1)
       [HideInInspector][HDR]_ColorZ("ColorZ",Color)=(1,1,1,1)
       [HideInInspector][HDR]_ColorEdge("ColorEdge",Color)=(1,1,1,1)
       [HideInInspector]_OutLineColor("OutLineColor",Color)=(1,1,1,1)
       [HideInInspector]_Width("Width",float)=0.1
       [HideInInspector]_Spacing("Spacing",float)=1
       [HideInInspector]_Speed("Speed",float)=1
       [HideInInspector]_EdgeSample("EdgeSample",Range(0,1))=1
       [HideInInspector]_NormalSensitivity("NormalSensitivity",float)=1
       [HideInInspector]_DepthSensitivity("NormalSensitivity",float)=1
       //[KeywordEnum(X,Y,Z)]_AXIS("Axis",float) = 1

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
        float4 _MainTex_ST;

        float4 _ColorX;
        float4 _ColorY;
        float4 _ColorZ;
        float4 _ColorEdge;
        float4 _OutLineColor;
        float _Width;
        float _Spacing;
        float _Speed;
        float _EdgeSample;
        float _NormalSensitivity;
        float _DepthSensitivity;
        CBUFFER_END


        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_CameraDepthNormalsTexture);
        SAMPLER(sampler_CameraDepthNormalsTexture);
        //TEXTURE2D(_CameraDepthTexture);
        //SAMPLER(sampler_CameraDepthTexture);
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
            #pragma multi_compile_local _AXIS_X _AXIS_Y _AXIS_Z

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

            int soble(v2f i);

            float4 frag(v2f i):SV_Target
            {
                int outline = soble(i);
                //返回轮廓    
                float4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
                float4 depthNormal = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture,sampler_CameraDepthNormalsTexture,i.texcoord);
                float depth01 = depthNormal.z * 1.0+depthNormal.w/255.0;//得到01线性的深度

                float3 WSPos = _WorldSpaceCameraPos + depth01*i.dirction*_ProjectionParams.z;//这样也可以得到世界坐标
                float3 WSPos01 = WSPos*_ProjectionParams.w;
                float3 Line = step(1-_Width,frac(WSPos/_Spacing));//线框
                float4 LineColor = Line.x*_ColorX+Line.y*_ColorY+Line.z*_ColorZ+outline*_OutLineColor;

                #ifdef _AXIS_X
                float mask = saturate(pow(abs(frac(WSPos01.x + _Time.y*0.1*_Speed)-0.75),10)*30);//在X轴方向计算mask
                mask += step(0.999,mask);
                #elif _AXIS_Y
                float mask = saturate(pow(abs(frac(WSPos01.y + _Time.y*0.1*_Speed)-0.25),10)*30);//在Y轴方向计算mask
                mask += step(0.999,mask);
                #elif _AXIS_Z
                float mask = saturate(pow(abs(frac(WSPos01.z + _Time.y*0.1*_Speed)-0.75),10)*30);//在Z轴方向计算mask
                mask += step(0.999,mask);
                #endif
                //返回掩码
                return mainTex*saturate(1-mask)+(LineColor+_ColorEdge)*mask;

            }

            int soble(v2f i)//定义索伯检测函数
            {
                float depth[4];
                float2 normal[4];
                float2 uv[4];
                uv[0] = i.texcoord+float2(-1,1)*_EdgeSample*_MainTex_TexelSize.xy;
                uv[1] = i.texcoord+float2(1,-1)*_EdgeSample*_MainTex_TexelSize.xy;
                uv[2] = i.texcoord+float2(-1,1)*_EdgeSample*_MainTex_TexelSize.xy;
                uv[3] = i.texcoord+float2(1,1)*_EdgeSample*_MainTex_TexelSize.xy;
                for(int t = 0;t<4;t++)
                {
                    float4 depthNormalTex = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture,sampler_CameraDepthNormalsTexture,uv[t]);
                    normal[t] = depthNormalTex.xy;//得到临时法线
                    depth[t] = depthNormalTex.z*1.0+depthNormalTex.w/255.0;//得到线性深度
				}
                //深度检测
                int Dep = abs(depth[0]-depth[3])*abs(depth[1]-depth[2])*_DepthSensitivity>0.01?1:0;
                //正常检测
                float2 nor = abs(normal[0]-normal[3]*abs(normal[1]-normal[2]))*_NormalSensitivity;
                int Nor = (nor.x+nor.y)>0.01?1:0;
                return saturate(Dep + Nor);
            }

            ENDHLSL
        }
    }
}
