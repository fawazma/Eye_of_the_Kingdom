// Eye of the Kingdom
// Unlimited Security Application
// Purpose: ServerConfiguration.
// ------------------------------------------------------------------


namespace UnlimitedSecurity.GUI.ServiceConfiguration
{
    public class ConfigurationAdapterHelper
    {
        private static readonly ILog Logger = LogManager.GetLogger(typeof(ConfigurationAdapterHelper));

        [SifPropertyDef("resource_loader")]
        public IResourceLoader ResourceLoader { get; set; }

        public static T GetConfiguration<T>(IServiceConfigurationManager manager)
        {
            T configuration = default(T);
            try
            {
                configuration = manager.GetConfiguration<T>();
            }
            catch (Exception e)
            {
                const string ERROR_MESSAGE = "Could not apply configuration, configuration not found. Keeping default SifNet configuration.";
                MachineException machineException = e as MachineException;
                if (machineException == null)
                {
                    Logger.Error(ERROR_MESSAGE, e);
                }
                else
                {
                    Logger.ErrorFormat("{0} ({1})", ERROR_MESSAGE, machineException.Message);
                }
            }
            return configuration;
        }

        public object InstantiateProgram(ISqlConfiguration sqlConfiguration, string connectionString, string pgSqlSifnet, string sqlSrvSifnet, params ExternalRef[] additionalRefs)
        {
            DatabaseType type = sqlConfiguration != null ? sqlConfiguration.DbType : DatabaseType.SqlServer;

            object program = null;
            try
            {
                List<ExternalRef> refs;
                switch (type)
                {
                    case DatabaseType.PostgreSql:
                        refs = new List<ExternalRef> { new ExternalRef("EXT_CONNECTION_STRING", string.IsNullOrWhiteSpace(connectionString) ? DefaultPropertyHolder.PostgreSqlConnectionString : connectionString) };
                        if (additionalRefs != null && additionalRefs.Length > 0) refs.AddRange(additionalRefs);
                        program = new ProgramBuilder().Build(GetSifXmlResource(pgSqlSifnet), refs);
                        break;
                    default:
                        refs = new List<ExternalRef> { new ExternalRef("EXT_CONNECTION_STRING", string.IsNullOrWhiteSpace(connectionString) ? DefaultPropertyHolder.SqlServerConnectionString : connectionString) };
                        if (additionalRefs != null && additionalRefs.Length > 0) refs.AddRange(additionalRefs);
                        program = new ProgramBuilder().Build(GetSifXmlResource(sqlSrvSifnet), refs);
                        break;
                }
            }
            catch (Exception e)
            {
                Logger.Error("Could not load database specific configuration.", e);
            }
            return program;
        }

        public XModule GetSifXmlResource(string resName)
        {
            return new XmlProgramLoader().LoadProgram(ResourceLoader.GetResourceAsTextReader(resName));
        }
    }
}
