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
        bool HasUpdate { get; }
        string Summary { get; }
    }

    public delegate void SignContentNotify(ISignContent content);

    public interface ISignContentControl
    {
        void BindToContent(ISignContent content);
        event SignContentNotify ContentChange;
    }

    class SignContentAttribute : Attribute
    {
        public SignContentAttribute(string name)
        {
            ContentName = name;
        }

        public string ContentName;
    }


    public class SignContentType
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

        public static SignContentType GetFromName(string name)
        {
            if (Types == null)
                EnumerateContentTypes();

            return TypeMap[name];
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
            return Create(GetFromName(name));
        }

        public static ISignContentControl CreateControl(SignContentType t)
        {
            object o = Assembly.GetCallingAssembly().CreateInstance(t.ContentClassType.FullName + "Control");
            if(o is ISignContentControl)
            {
                return (ISignContentControl)o;
            }
            throw new Exception("No content control available for type: " + t.ContentClassType.FullName);
        }

        public static ISignContentControl CreateControl(string name)
        {
            return CreateControl(GetFromName(name));
        }
    }
}
