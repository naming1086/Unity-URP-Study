﻿Shader "URP/URPDepth"
{
    Properties
    {
        _MainTex ("Base Texture", 2D) = "white" {}
        _BaseColor("Base Color",Color)=(1,1,1,1)
        _DepthOffset("DepthOffset",float) = 1
        [HDR]_EmissionColor("EmissionColor",Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "Queue"="Transparent" 
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;//ST = Sampler Texture 采样器纹理
        half4 _BaseColor;
        float _DepthOffset;
        float4 _EmissionColor;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        SAMPLER(_CameraDepthTexture);

        struct a2v//这就是a2v 应用阶段传递模型给顶点着色器的数据
        {
            float4 positionOS : POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord : TEXCOORD;
        };

        struct v2f//这就是v2f 顶点着色器传递给片元着色器的数据
        {
            float4 positionCS : SV_POSITION;//必须
            float2 texcoord : TEXCOORD;

            float4 sspos:TEXCOORD2;
            float3 positionWS:TEXCOORD3;
            float3 normalWS:TEXCOORD4;
        };


        ENDHLSL

        Pass
        {        
            Tags
            {
                "LightMode"="UniversalForward"
                "RenderType"="Transparent"
            }
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);
                //屏幕坐标sspos,xy保存为未透除的屏幕uv,zw不变
                o.sspos.xy = o.positionCS.xy*0.5+0.5*float2(o.positionCS.w,o.positionCS.w);
                o.sspos.zw = o.positionCS.zw;
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.normalWS = normalize(TransformObjectToWorldNormal(i.normalOS.xyz));

                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                float2 uv = i.texcoord;
                uv.x+=_Time.y*0.2;//滚uv，以每秒钟滚0.2圈的速度旋转
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord)*_BaseColor;

                //开始计算屏幕uv
                i.sspos.xy/=i.sspos.w;//透除
                #ifdef UNITY_UV_STARTS_AT_TOP//判断当前平台是OpenGL还是dx
                i.sspos.y=1-i.sspos.y;
                #endif//得到正常的屏幕uv，也可以通过i.positionCS.xy/_ScreenParams.xy来得到屏幕uv
                //计算(山寨简化版)菲涅尔
                float3 WS_View = normalize(_WorldSpaceCameraPos-i.positionWS);
                float fre=(1-dot(i.normalWS,WS_View))*_DepthOffset;

                //计算缓冲区深度，模型深度
                float4 depthColor = tex2D(_CameraDepthTexture,i.sspos.xy);
                float depthBuffer = Linear01Depth(depthColor.x,_ZBufferParams);//得到线性的深度缓冲

                //计算模型深度
                float depth = i.positionCS.z;
                depth = Linear01Depth(depth,_ZBufferParams);//得到模型的线性深度
                float edge = saturate(depth-depthBuffer+0.005)*100*_DepthOffset;//计算接触光

                //计算扫光,这步看不懂建议用连连看还原，这是一个做特效的通用公式
                float flow = saturate(pow(1-abs(frac(i.positionWS.y*0.3-_Time.y*0.2)-0.5),10)*0.3);
                float4 flowColor = flow*_EmissionColor;

                return float4(mainTex.xyz,edge+fre)+flowColor;
                
            }
            ENDHLSL  //ENDCG
        }
    }
}
