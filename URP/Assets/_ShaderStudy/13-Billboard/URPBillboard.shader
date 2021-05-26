Shader "URP/URPBillboard"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}      
        [HDR]_BaseColor("Base Color",Color)=(1,1,1,1)
        _Rotate("Rotate",Range(0,3.14))=0
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "Queue"="Overlay" 
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        float _Rotate;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);

        struct a2v
        {
            float4 positionOS:POSITION;
            float2 texcoord:TEXCOORD;
		};

        struct v2f
        {
            float4 positionCS:SV_POSITION;
            float2 texcoord:TEXCOORD;
            float4 color:COLOR;
		};
        ENDHLSL

        Pass
        {
            Tags
            {
			    "LightMode"="UniversalForward"
                "RenderType"="Overlay"
            }
            Blend one one
            ZWrite off
            ZTest always

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            v2f vert (a2v i)
            {
                v2f o;
                o.texcoord = TRANSFORM_TEX(i.texcoord,_MainTex);
                float4 pivotWS = mul(UNITY_MATRIX_M,float4(0,0,0,1));
                float4 pivotVS = mul(UNITY_MATRIX_V,pivotWS);
                float scaleX = length(float3(UNITY_MATRIX_M[0].x,UNITY_MATRIX_M[1].x,UNITY_MATRIX_M[2].x));
                float scaleY = length(float3(UNITY_MATRIX_M[0].y,UNITY_MATRIX_M[1].y,UNITY_MATRIX_M[2].y));
                //float scaleZ = length(float3(UNITY_MATRIX_M[0].z,UNITY_MATRIX_M[1].z，UNITY_MATRIX_M[2].z));

                //定义一个旋转矩阵
                float2x2 rotateMatrix = {cos(_Rotate),-sin(_Rotate),sin(_Rotate),cos(_Rotate)};
                //用来临时存放旋转后的坐标
                float2 pos = i.positionOS.xy*float2(scaleX,scaleY);
                pos = mul(rotateMatrix,pos);
                float4 positionVS = pivotVS + float4(pos,0,1);//深度取得轴心位置深度，xy进行缩放
                o.positionCS = mul(UNITY_MATRIX_P,positionVS);

                float sampleCount = 3;//这个值越大，线性插值精度越高，计算量越大
                float singeAxisCount = 2*sampleCount+1;
                float totalCounts = pow(singeAxisCount,2);
                float passCount = 0;
                float sampleRange = 0.2;//中心区域比例
                float pivotDepth = -pivotVS.z;//取相机空间轴心的线性深度
                float4 pivotCS = mul(UNITY_MATRIX_P,pivotVS);//得到裁剪空间的轴心位置
                for(int x = -sampleCount;x<=sampleCount;x++)
                {
                    for(int y = -sampleCount;y<=sampleCount;y++)
                    {
                        float2 samplePosition = pivotCS.xy + o.positionCS.xy*sampleRange*float2(x,y)/singeAxisCount;//裁剪空间的采样位置
                        float2 SSuv = samplePosition/o.positionCS.w*0.5+0.5;//把裁剪空间手动透除，变换到NDC空间下，并根据当前平台判断是否翻转y轴
                        #ifdef UNITY_UV_STARTS_AT_TOP
                        SSuv.y = 1- SSuv.y;
                        #endif
                        if(SSuv.x<0||SSuv.x>1||SSuv.y<0||SSuv.y>1)
                        continue;
                        float sampleDepth = SAMPLE_TEXTURE2D_LOD(_CameraDepthTexture,sampler_CameraDepthTexture,SSuv,0).x;//采样当前像素点深度值
                        sampleDepth = LinearEyeDepth(sampleDepth,_ZBufferParams);//把它变换到线性空间
                        passCount += sampleDepth > pivotDepth?1:0;//把采样点的深度和模型的轴心深度进行对比

                    }
                }

                //o.positionCS =TransformObjectToHClip(i.positionOS.xyz);
                o.color = _BaseColor*_BaseColor.a;
                o.color *= passCount/totalCounts;
                o.color *= smoothstep(0.1,2,pivotDepth);//在考虑个深度方向的蒙板，深度小于0.1时，完全不可见，深度大于2时，可见
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
                return tex*i.color;
            }
            ENDHLSL
        }
    }
}
