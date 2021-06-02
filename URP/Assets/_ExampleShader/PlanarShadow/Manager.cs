using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class Manager : MonoBehaviour
{
    public Button btn;

    float deltaTime = 0.0f;

    public GameObject[] gos;

    public Material mat_1;
    public Material mat_2;
    public Material mat_1_no;
    public Material mat_2_no;

    // Start is called before the first frame update
    void Start()
    {
        btn.onClick.AddListener(OpenOrColseShadow);
    }

    private void OpenOrColseShadow()
    {
        bool hasShadow;
        int layer;
        if (gos[0].layer == LayerMask.NameToLayer("Default"))
        {
            layer = LayerMask.NameToLayer("Shadow");
            hasShadow = true;
        }
        else
        {
            layer = LayerMask.NameToLayer("Default");
            hasShadow = false;
        }

        for (int i = 0; i < gos.Length; i++)
        {
            gos[i].layer = layer;
            if (i < 6)
            {
                gos[i].GetComponent<SkinnedMeshRenderer>().material = hasShadow?mat_1: mat_1_no;
            }
            else
            {
                gos[i].GetComponent<SkinnedMeshRenderer>().material = hasShadow ? mat_2 : mat_2_no;
            }
        }
    }
}

public class TestClass
{
    int id;

    public void SetData(TestClass other)
    {
        var test = new TestClass();
        test.id = 10;
        other.id = this.id;
    }
}
