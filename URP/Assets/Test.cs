using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Test : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        var gos = new GameObject[10];
        for (int i = 0; i < 10; i++)
        {
            gos[i] = new GameObject();
        }

        var objects = (Object[])gos;

        var gooos = (GameObject[])objects;

        Debug.Log("");
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
