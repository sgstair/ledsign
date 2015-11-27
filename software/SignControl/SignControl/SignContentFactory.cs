using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;

namespace SignControl
{
    public interface ISignContent
    {
        IEnumerable<SignElement> GetElements();

    }


    class SignContentAttribute : Attribute
    {
        public SignContentAttribute(string name)
        {
            ContentName = name;
        }

        public string ContentName;
    }


    class SignContentType
    {
        public string Name;
        
        internal Type ContentClassType;
    }

    class SignContentFactory
    {
        static SignContentType[] Types = null;
        static Dictionary<string, SignContentType> TypeMap;

        public static IEnumerable<SignContentType> EnumerateContentTypes()
        {
            if(Types == null)
            {
                List<SignContentType> generateTypes = new List<SignContentType>();
                TypeMap = new Dictionary<string, SignContentType>();
                Assembly a = Assembly.GetCallingAssembly();
                foreach(Type t in a.GetTypes())
                {
                    SignContentAttribute sc = t.GetCustomAttribute<SignContentAttribute>(false);
                    if(sc != null)
                    {
                        SignContentType sct = new SignContentType();
                        sct.Name = sc.ContentName;
                        sct.ContentClassType = t;
                        generateTypes.Add(sct);
                        TypeMap.Add(sct.Name, sct);
                    }
                }
                Types = generateTypes.ToArray();
            }
            return Types;
        }

        public static ISignContent Create(SignContentType t)
        {
            object o = Assembly.GetCallingAssembly().CreateInstance(t.ContentClassType.FullName);
            if(o is ISignContent)
            {
                return (ISignContent)o;
            }
            throw new Exception("Mislabeled Sign content type: " + t.ContentClassType.FullName);
        }


        public static ISignContent Create(string name)
        {
            if(Types == null)
                EnumerateContentTypes();

            return Create(TypeMap[name]);
        }
    }
}
