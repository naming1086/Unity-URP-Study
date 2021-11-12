//曲面细分算法展示

Shader "Unlit/SurfaceSubdivision_Test01"
{
    Properties
    {
        _TessellationUniform("TessellationUniform",Range(1,64)) = 1
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
        //引入曲面细分的头文件
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float _TessellationUniform;
        CBUFFER_END
        
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma target 4.6
            #pragma vertex vert
            #pragma fragment frag
            #pragma hull hs
            #pragma domain ds

            struct a2v
		    {
			    float4 positionOS : POSITION;
		    };

		    struct v2f
		    {
			    float3 positionCS : TEXCOORD0;
		    };

            //这个函数应用在domain函数中，用来空间转换的函数
            v2f vert(a2v i)
            {
                v2f o;
                //o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionCS = i.positionOS.xyz;
                return o;
            }

            struct OutputPatchConstant 
            { 
                //不同的图元，该结构会有所不同
                //该部分用于Hull Shader里面
                //定义了patch的属性
                //Tessellation Factor和Inner Tessellation Factor
                float edge[3] : SV_TESSFACTOR;
                float inside  : SV_INSIDETESSFACTOR;
            };

            OutputPatchConstant hsconst (InputPatch<v2f,3> patch)
            {
                //定义曲面细分的参数
                OutputPatchConstant o;
                o.edge[0] = _TessellationUniform;
                o.edge[1] = _TessellationUniform;
                o.edge[2] = _TessellationUniform;
                o.inside  = _TessellationUniform;
                return o;
            }

            //顶点着色器结构的定义
            struct HullOut{
                float3 position : TEXCOORD0;
            };

            [domain("tri")]//确定图元，quad,triangle等
            [partitioning("integer")]//拆分edge的规则，equal_spacing,fractional_odd,fractional_even
            [outputtopology("triangle_cw")]
            [outputcontrolpoints(3)]      //不同的图元会对应不同的控制点
            [patchconstantfunc("hsconst")]//一个patch一共有三个点，但是这三个点都共用这个函数
            [maxtessfactor(64.0f)]
            HullOut hs (InputPatch<v2f,3> patch,uint id : SV_OutputControlPointID){
                //定义hullshaderV函数
                HullOut hout;
                hout.position=patch[id].positionCS;
                return hout;
            }

            struct DomainOut
            {
                float4 position:SV_POSITION;    
            };

            [domain("tri")]//同样需要定义图元
            DomainOut ds (OutputPatchConstant tessFactors, const OutputPatch<HullOut,3> patch,float3 bary :SV_DOMAINLOCATION)
            //bary:重心坐标
            {
                DomainOut dout;
                float3 p = patch[0].position*bary.x + patch[1].position*bary.y + patch[2].position*bary.z;
                dout.position=TransformObjectToHClip(p.xyz);
                return dout;
            }

            float4 frag (DomainOut i) : SV_Target
            {
                return float4(1.0,1.0,1.0,1.0);
            }
            ENDHLSL
        }
    }
}
