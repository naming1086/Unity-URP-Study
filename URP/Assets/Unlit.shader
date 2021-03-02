Shader "URPCustom/Unlit"
{
    Properties
    {
        _BaseMap("Base Texture",2D)="white"{}
        _BaseColor("Base Color",Color)=(1,1,1,1)
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
        /*
        使用的底层代码也发生了变化，默认包含的头文件需要从CG的 #include "UnityCG.cginc"
        改为#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        除了核心的工具库外，其他如光照、阴影等要包含的头文件也需要修改。
        使用了不同的头文件后，自然一些使用各种工具函数也不一样。
        */

        //CG中核心代码库 #include "UnityCG.cginc"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        /*
        为了支持SRP Batcher（具体看前一篇），Shader中要将所有暴露出的参数（贴图除外）
        给包含到CBUFFER_START(UnityPerMaterial)与CBUFFER_END之间。
        并且为了保证之后的每个Pass都能拥有一样的CBUFFER，
        这一段代码需要写在SubShader之内，其它Pass之前。
        */

        //除了贴图外，要暴露在Inspector面板上的变量都需要缓存到CBUFFER中
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        half4 _BaseColor;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            /*
            URP中实际会包含多个Pass，但是只有一个渲染Pass，
            要让管线能区分这些不同，就需要给这些Pass给Tags进行标记。
            */

            Tags{"LightMode"="UniversalForward"}//这个Pass最终会输出到颜色缓冲里

            /*
            在Built-In管线中我们常使用CG语言来写Shader，但是在URP中，一般使用HLSL。
            CG语言和HLSL语言都是C风格的语言，写法上没有太大差别。
            用于包含CG语言的CGPROGRAM和ENDCG需要改成包含HLSL的HLSLPROGRAM和ENDHLSL。
            */
            HLSLPROGRAM //CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct a2v//这就是a2v
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD;
            };

            struct v2f//这就是v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD;
            };

            TEXTURE2D(_BaseMap);//在CG中会写成sampler2D _MainTex;
            SAMPLER(sampler_BaseMap);

            v2f vert(a2v IN)
            {
                v2f OUT;
                //在CG里面，我们这样转换空间坐标 o.vertex = UnityObjectToClipPos(v.vertex);
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = positionInputs.positionCS;

                OUT.uv=TRANSFORM_TEX(IN.uv,_BaseMap);
                return OUT;
            }

            float4 frag(v2f IN):SV_Target
            {
                //在CG里，我们这样对贴图采样 fixed4 col = tex2D(_MainTex, i.uv);
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);                
                return baseMap * _BaseColor;
            }
            ENDHLSL  //ENDCG
        }
    }
}
