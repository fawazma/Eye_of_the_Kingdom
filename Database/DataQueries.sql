IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='alarm_event' AND xtype='U')
	CREATE TABLE alarm_event
	(
		Id BIGINT NOT NULL IDENTITY(1,1),
		alarmIdentifier UNIQUEIDENTIFIER NOT NULL,
		eventIdentifier UNIQUEIDENTIFIER NOT NULL,
		CONSTRAINT PK_alarm_event PRIMARY KEY (Id)
	)

IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='alarm_priority' AND xtype='U')
	CREATE TABLE [dbo].[alarm_priority](
		[Value] [int] NOT NULL,
		[Version] [int] NOT NULL,
		[Data] [varbinary](max) NOT NULL,
		CONSTRAINT PK_alarm_priority PRIMARY KEY (Value,Version)
	) 

IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='alarms' AND xtype='U')
	CREATE TABLE [dbo].[alarms](
		[Id] [uniqueidentifier] NOT NULL,
		[Version] [bigint] NOT NULL,
		[Priority] [tinyint] NOT NULL,
		[State] [tinyint] NOT NULL,
		[LastModifiedTimestamp] [bigint] NOT NULL,
		[CreatedTimestamp] [bigint] NOT NULL,
		[Data] [varbinary](8000) NOT NULL,
	 CONSTRAINT [PK_alarms] PRIMARY KEY CLUSTERED 
	(
		[Id] ASC,
		[Version] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]

IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = object_id('alarms') AND NAME ='TimestampIndex')
BEGIN
	DROP INDEX TimestampIndex ON [dbo].[alarms]
END

IF NOT EXISTS (
  SELECT * 
  FROM   sys.columns 
  WHERE  object_id = OBJECT_ID(N'[dbo].[alarms]') 
         AND name = 'CreatedTimestamp'
)
ALTER TABLE [dbo].[alarms] ADD CreatedTimestamp bigint;

IF NOT EXISTS(SELECT * FROM sys.indexes WHERE object_id = object_id('alarms') AND NAME ='alarms_index')
BEGIN
	ALTER TABLE [dbo].[alarms] DROP CONSTRAINT [PK_alarms]
	CREATE CLUSTERED INDEX alarms_index ON [dbo].[alarms] (CreatedTimestamp DESC, LastModifiedTimestamp DESC)
	ALTER TABLE [dbo].[alarms] ADD CONSTRAINT [PK_alarms] PRIMARY KEY (Id, Version)
END

IF NOT EXISTS(SELECT * FROM sys.indexes WHERE object_id = object_id('alarms') AND NAME ='alarm_priority_index')
BEGIN
	CREATE NONCLUSTERED INDEX alarm_priority_index ON [dbo].[alarms] (priority)
END

IF NOT EXISTS(SELECT * FROM sys.indexes WHERE object_id = object_id('alarms') AND NAME ='alarm_state_index')
BEGIN
	CREATE NONCLUSTERED INDEX alarm_state_index ON [dbo].[alarms] (state)
END

IF NOT EXISTS(SELECT * FROM sys.indexes WHERE object_id = object_id('alarm_event') AND NAME ='alarm_event_index')
BEGIN
	CREATE NONCLUSTERED INDEX alarm_event_index ON [dbo].[alarm_event] (alarmIdentifier, eventIdentifier)
END