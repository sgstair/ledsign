using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;

namespace SignControl
{
    class ReflectionHelper
    {
        public static IEnumerable<T> GetTypesForAttribute<T>() where T : Attribute
        {

            Assembly a = Assembly.GetCallingAssembly();
            foreach (Type t in a.GetTypes())
            {
                T sc = t.GetCustomAttribute<T>(false);
                if (sc != null)
                {
                    yield return sc;
                }
            }
        }
    }
}
