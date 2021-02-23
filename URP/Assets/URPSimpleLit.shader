Shader "URPCustom/URPSimpleLit"
{
    Properties
    {
        _BaseMap("Base Texture",2D)="white"{}
        _BaseColor("Base Color",Color)=(1,1,1,1)
        _SpecularColor("SpecularColor",Color)=(1,1,1,1)//高光颜色
        _Smoothness("Smoothness",float)=10//表面平滑度
        _Cutoff("Cutoff",float)=0.5//隔断
    }
    SubShader
    {
        Tags 
        { 
            //在SubShader中需要声明这个Shader使用的是URP。
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Geometry"
            "RenderType"="Opaque"      
        }
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        float4 _BaseColor;
        float4 _SpecularColor;
        float _Smoothness;
        float _Cutoff;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "URPSimpleLit" 
            Tags{"LightMode"="UniversalForward"}

            
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma vertex vert
            #pragma fragment frag

            //应用阶段传递模型数据给顶点着色器
            struct Attributes//这就是a2v
            {
                float4 positionOS : POSITION;//模型空间顶点位置
                float4 normalOS : NORMAL;//顶点法线
                float2 uv : TEXCOORD0;//顶点的纹理坐标，TEXCOORD0表示第一组纹理坐标
            };

            //顶点着色器传递数据给片元着色器
            struct Varings//这就是v2f
            {
                float4 positionCS : SV_POSITION;//裁剪空间顶点坐标
                float2 uv : TEXCOORD0;//TEXCOORD0~7常用于输出纹理坐标
                float3 positionWS:TEXCOORD1;
                float3 viewDirWS:TEXCOORD2;
                float3 normalWS:TEXCOORD3;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            Varings vert(Attributes IN)
            {
                Varings OUT;
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);//获取输入顶点坐标信息
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz);//获取输入顶点法线信息
                OUT.positionCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;
                //视线方向（ViewDir) 先获取相机位置
                OUT.viewDirWS = GetCameraPositionWS() - positionInputs.positionWS;
                //法线（NormalDir）
                OUT.normalWS = normalInputs.normalWS;
                OUT.uv=TRANSFORM_TEX(IN.uv,_BaseMap);
                return OUT;
            }

            float4 frag(Varings IN):SV_Target
            {
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);   
                //计算主光
                Light light = GetMainLight();//获取主光源
                float3 lightDirWS = light.direction;                          
                half3 diffuse = baseMap.xyz*_BaseColor*LightingLambert(light.color, light.direction, IN.normalWS);//Lambert光照模型
                half3 specular = LightingSpecular(light.color, light.direction, normalize(IN.normalWS), normalize(IN.viewDirWS), _SpecularColor, _Smoothness);//高光
                //计算附加光照
                uint pixelLightCount = GetAdditionalLightsCount();//获取额外灯光数量
                for(uint lightIndex = 0;lightIndex<pixelLightCount;++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex,IN.positionWS);//获取额外灯光
                    diffuse += LightingLambert(light.color, light.direction, IN.normalWS);
                    specular += LightingSpecular(light.color, light.direction, normalize(IN.normalWS), normalize(IN.viewDirWS), _SpecularColor, _Smoothness);
				}

                half3 color=baseMap.xyz*diffuse*_BaseColor+specular;
                clip(baseMap.a-_Cutoff);

                return float4(color,1);;
            }
            ENDHLSL  //ENDCG
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _GLOSSINESS_FROM_BASE_ALPHA

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment


            //由于这段代码中声明了自己的CBUFFER，与我们需要的不一样，所以我们注释掉他
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            //它还引入了下面2个hlsl文件
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}
