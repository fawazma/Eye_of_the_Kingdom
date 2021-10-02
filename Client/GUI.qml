// Eye of the Kingdom
// Unlimited Security Application
// Purpose: Graphical User Interface.
// ------------------------------------------------------------------

import GUI.diagnostics 1.0 as Diagnostics
import GUI.sandbox3d 1.0 as Sandbox3d
import style 1.0
import 'HealthMonitor' as HealthMonitor
import 'PerspectiveSelectionStrategy' as PerspectiveSelectionStrategy
import 'Evidences' as Evidences
import GUI.app.initialization 1.0 as InitializationSystem
import GUI.USEcurity.permissions 1.0 as Permissions
import GUI.USEcurity.rules 1.0 as Rules
import 'PerspectiveLayouts' as PerspectiveLayouts
import 'PerspectiveComponents/ui' as PerspectiveUi

RootResolutionScope {
	id: main

	name: "cc"

	property alias currentPerspective: globalPerspectiveManager.currentPerspective
	property alias globalSearchPanel: globalSearchContainer
	property QtObject world
	property QtObject defaultMap2D: Maps.Map2DView { id: map2D; visible: false; active: true }
	property QtObject defaultFloorView: Sandbox3dFloorView { property QtObject interactionController: StandardFloorViewInteractionController {} }
	property QtObject globalActiveConfiguration: globalConfigurationCache.activeConfiguration
	property QtObject worldLayersFilter: LayersFilter { world: main.world }

	onGlobalActiveConfigurationChanged: {
		if (!globalActiveConfiguration || !globalActiveConfiguration.layersConfigurationData)
			return;

		worldLayersFilter.hiddenLayers = globalActiveConfiguration.layersConfigurationData.hiddenLayers;
		worldLayersFilter.defaultLayers = globalActiveConfiguration.layersConfigurationData.defaultLayers;
	}

	function quit() {
		if (globalProcedureEditorController.running) {
			Utilities.warning(qsTr("Warning"),qsTr("Please exit the Procedure Editor before closing."))
			return;
		}
		closing(); // Signal that now is your chance to clean up.

		// Quit Application. For a clean shutdown we make sure that world objects
		// are unreferenced and perspective UI is destroyed before destroying
		// core objects and managers.
		try {
			main.currentPerspective = null;
			main.world = null;
		} catch (e) { }
		Qt.quit();
	}

	signal closing
	onClosing: {
		if (!globalUserRegistryCache.callingUser || !globalUserRegistryCache.callingUser._idData) {
			logger.error("Cannot generate log out event: calling user is null");
			return;
		}

		var logOut = logOutEvent.createObject(null)
		logger.debug("GraphicsUI", "User " + logOut.username + " logged out from " + logOut.machineName + " monitoring the site: " + TypeHelper.uuidToString( logOut.siteId ) )
		_private.pushEvent(logOut)
	}

	function getServiceReferenceDisplayName(serviceReference) {
		if(!serviceReference) return "";
		var lastIndex = serviceReference.name.lastIndexOf("(");
		if(lastIndex === -1) return serviceReference.name;

		return serviceReference.name.slice(0, lastIndex).trim();
	}

	// Main application object derived from QtObject Application
	Unlimited_Security.Application {
		id: application

		applicationName: "Graphics UI"
		applicationFullName: globalActiveConfiguration && globalActiveConfiguration.customApplicationName || "Unlimited_Security 3D Graphics UI"
		applicationCopyright: "2006-2018 GUI"
		organizationName: "GUI"
		windowIcon: "app:GraphicsUI.ico"


		Sandbox3d.Sandbox3dEngine {
			id: globalSandbox3dEngine
			forceOffAngleProjectionsVisible: actionForceOffAngleProjections.checked
		}

		// Disabling transition kills guard tours.
		//		Binding { target: defaultFloorView.movementController; property: "transitionEnabled"; value: false; }

		OmniUI.AwayFromKeyboardEventFilter {
			id: awayFromKeyboardEventFilter
			target: globalApplication

			onIsAwayFromKeyboardChanged: {
				if (!isAwayFromKeyboard && globalSoundPlayer.looping && hasFocus) {
					globalSoundPlayer.stop();
					flashingMouseArea.resetIndicateNewAlarm();
				}
			}

			onHasFocusChanged: {
				if (!isAwayFromKeyboard && globalSoundPlayer.looping && hasFocus) {
					globalSoundPlayer.stop();
					flashingMouseArea.resetIndicateNewAlarm();
				}
			}
		}

		PerspectiveLayouts.PerspectiveLayoutDatabase { id: globalPerspectiveLayoutDatabase }

		PerspectiveManager {
			id: globalPerspectiveManager

			// TODO: Evaluate if next line does something...
			property QtObject dashboardPerspective: dashboardPerspective;

			perspectiveContainer: mainPerspectiveContainer
			nextPerspectiveStrategy: PerspectiveSelectionStrategy.FirstAvailablePerspectiveStrategy {
				localPerspectives: localPerspectivesColumn
				remotePerspectives: remotePerspectivesColumn
			}
		}

		Component {
			id: globalPerspectiveLocator

			PerspectiveUi.PerspectiveLocator {
				context: Item {
					property QtObject world: main.world;
					property QtObject mapResolver: _private.localServices.mapResolver;
					property QtObject placemarkIconProvider: globalPlacemarkIconProvider;
					property QtObject selectionController: globalSelectionController;
					property QtObject map: world && world.rootFloor || null
				}
			}
		}

		PermissionsManager {
			id: globalPermissionsManager
			permissionsProvider: _private.localServices.permissionsProvider
			sopDatastoreCache: _private.localServices.caches.sopDatastoreCache
		}

		AlarmPerspectiveManager {
			id: globalAlarmPerspectiveManager

			alarmControl: _private.localServices.alarmControl
			perspectiveManager: globalPerspectiveManager
			perspectiveContextBuilder: globalFlexiblePerspectiveContextBuilder
			selectionController: globalSelectionController
			sopDatastoreCache: globalPerspectiveManager.currentPerspective && globalPerspectiveManager.currentPerspective.context && globalPerspectiveManager.currentPerspective.context.sopDatastoreCache

			siteId: globalSiteRegistryCache.currentSiteData && globalSiteRegistryCache.currentSiteData._id || TypeHelper.nullUuid()
			isCMSSite: siteTypeInfoMembers.isCMSSite

			remoteServices: _private.remoteServices
		}

		InvestigationPerspectiveManager {
			id: globalInvestigationPerspectiveManager

			perspectiveManager: globalPerspectiveManager
			perspectiveContextBuilder: globalFlexiblePerspectiveContextBuilder
		}

		ShortcutPerspectiveManager {
			id: globalShortcutPerspectiveManager

			perspectiveContextBuilder: globalFlexiblePerspectiveContextBuilder
			perspectiveManager: globalPerspectiveManager
			layoutDatabase: globalPerspectiveLayoutDatabase
		}

		ResourcePerspectiveManager {
			id: globalResourcePerspectiveManager

			perspectiveManager: globalPerspectiveManager
			perspectiveContextBuilder: globalFlexiblePerspectiveContextBuilder
			eventSourceLocationProvider: _private.localServices.eventSourceLocationProvider
		}

		Federation.RemoteMonitoringAccessTracker {
			id: remoteMonitoringAccessTracker

			siteId: !!globalSiteRegistryCache.currentSiteData && globalSiteRegistryCache.currentSiteData._id || TypeHelper.nullUuid()

			onAccessEnabledChanged: {
				indicateRMSaccessEnabledChange = accessEnabled && monitoredSitesData.length > 0;

				if (indicateRMSaccessEnabledChange && !globalSoundPlayer.looping) { // don't override looping sound with a one shot sound
					var rmsSound = globalActiveConfiguration && globalActiveConfiguration.rmsSound || OmniUI.SoundBank.RMSEnabled;
					if (rmsSound === OmniUI.SoundBank.Default) { rmsSound = OmniUI.SoundBank.RMSEnabled; }
					if (rmsSound !== OmniUI.SoundBank.None) { globalSoundPlayer.playSound(rmsSound, false); }
				}

				if (!accessEnabled) {
					globalPerspectiveManager.openDefaultPerspective();
					var alarmPerspectives = globalAlarmPerspectiveManager.remoteAlarmPerspectives.toObjectList();
					alarmPerspectives.forEach(function(perspective) {
						globalAlarmPerspectiveManager.closeAlarmPerspective(perspective);
					});
				}
			}

			property bool indicateRMSaccessEnabledChange: false	// Becomes true when RMS access enabled changed
			property variant monitoredSitesData: TypeHelper.uuidVectorToUuidList(monitoredSites)

			onMonitoredSitesDataChanged: {
				indicateRMSaccessEnabledChange = accessEnabled && monitoredSitesData.length > 0;

				var newMonitoredSites = {};
				var previouslyMonitoredSites = currentlyMonitoredSites;
				for (var i = 0; i < monitoredSitesData.length; ++i)
					newMonitoredSites[TypeHelper.uuidToString(monitoredSitesData[i])] = true;

				var lostSites = [];

				for (var j = 0 in previouslyMonitoredSites) {
					if (!newMonitoredSites[j])
						lostSites.push(j);
				}

				var alarmPerspectives = globalAlarmPerspectiveManager.remoteAlarmPerspectives.toObjectList();
				var closeLast = null;
				alarmPerspectives.forEach(function(perspective) {

					var alarmSite = perspective && perspective.context && perspective.context.alarmController && perspective.context.alarmController.alarm && perspective.context.alarmController.alarm.siteId || TypeHelper.nullUuid();
					if (lostSites.some(function(site) { return TypeHelper.uuidEquals(site, alarmSite) })) {
						if (perspective !== currentPerspective)
							globalAlarmPerspectiveManager.closeAlarmPerspective(perspective);
						else
							closeLast = perspective;
					}
				});

				// Close the Current perspective last to avoid activating all perspectives before closing them.
				if (closeLast)
					globalAlarmPerspectiveManager.closeAlarmPerspective(closeLast);

				if (lostSites.length > 0) {
					var lostSitesStr = "";
					for (var k = 0; k < lostSites.length; ++k) {
						if (k > 0)
							lostSitesStr += ", ";

						lostSitesStr += globalSiteRegistryCache.siteName(TypeHelper.stringToUuid(lostSites[k]));
					}
				}

				currentlyMonitoredSites = newMonitoredSites;
			}

			InterfaceBinding on configService { value: _private.remoteServices.remoteMonitoringConfigurationService }

			property variant currentlyMonitoredSites: ({})
	}

		Permissions.FeedPermissionProviderAggregator {
			id: globalFeedPermissionProvider

			property variant serviceReferences: _private.localServices.serviceFinder.sequenceNumber && _private.localServices.serviceFinder.findAllServiceReferencesDataByType("GUI.USEcurity.permissions.FeedPermissionProvider")
			property variant remoteServiceReferences: _private.remoteServices.dispatcherReady ? _private.remoteServices.serviceRegistryCache.sequenceNumber && _private.remoteServices.serviceRegistryCache.findAllServiceReferencesDataByType("GUI.USEcurity.permissions.FeedPermissionProvider") : null
			property variant permissionProviderRemotes: []
			property variant healthStatus: []

			property QtObject acccessTrackerConnection: Connections {
				target: remoteMonitoringAccessTracker
				onAccessEnabledChanged: globalFeedPermissionProvider.updateProviders();
			}

			onServiceReferencesChanged: updateProviders();
			onRemoteServiceReferencesChanged: updateProviders();

			property QtObject healthStatusAggregator: HealthStatusAggregator { }

			function updateProviders() {
				clear();
				destroyRemotes()
				clearHealthStatus();;

				var localReferences = serviceReferences || [];
				var references = localReferences;

				if (remoteMonitoringAccessTracker.accessEnabled && remoteServiceReferences)
					references = references.concat(remoteServiceReferences);

				var permissionProviders = [];
				var addedHealthStatus = [];

				for(var i = 0; i < references.length; ++i) {
					var permissionProvider = feedPermissionProviderRemote.createObject(globalFeedPermissionProvider);
					permissionProvider.serviceReferenceData = references[i];
					permissionProvider.dispatcher = i < localReferences.length ? _private.localServices.rpcClient.iRpcDispatcher : _private.remoteServices.iRpcDispatcher;
					permissionProviders.push(permissionProvider);

					//Keep track of the health of each FeedPermissionProvider
					var healthStatusWatchdog = feedPermissionProviderHealthStatusWatchdog.createObject(globalFeedPermissionProvider);
					healthStatusWatchdog.objectName = getServiceReferenceDisplayName(references[i]);
					healthStatusWatchdog.remote = permissionProvider;
					healthStatusAggregator.observables.append(healthStatusWatchdog);
					addedHealthStatus.push(healthStatusWatchdog);
				}

				healthStatus = addedHealthStatus;
				permissionProviderRemotes = permissionProviders;
				globalFeedPermissionProvider.feedPermissionProviders = permissionProviders;
			}

			function clearHealthStatus() {
				var status = healthStatus;
				for(var i = 0; !!status && i < status.length; ++i) {
					healthStatusAggregator.observables.remove(status[i]);
					status[i].deleteLater();
				}

				healthStatus = [];
			}

			function destroyRemotes() {
				if (!permissionProviderRemotes) return;

				var providers = permissionProviderRemotes;
				for(var i = 0; i < providers.length; ++i)
					providers[i].deleteLater();

				permissionProviderRemotes.length = 0;
			}
		}

		Component {
			id: feedPermissionProviderRemote
			Permissions.FeedPermissionProviderRemote { }
		}
		Component {
			id: feedPermissionProviderHealthStatusWatchdog
			Watchdog.RemoteWatchdog {
				name: objectName;
				onNormalChanged: if(normal) globalFeedPermissionProvider.loadPermissions();
			}
		}

		OmniQml.ApplicationWindow {
			id: globalApplicationWindow
			applicationTitle: qsTr("%1 (%2) - Licensed to: %3  -  %4 - User: %5").arg(application.applicationFullName)
				.arg(application.applicationVersion)
				.arg(licenseFetcher.issuedTo)
				.arg(licenseFetcher.expiresIn)
				.arg(globalUserRegistryCache.userName);

			key: "GraphicsUIApplicationWindow"
			defaultWindowState: Qt.WindowMaximized

			Unlimited_Security.EventFilter {
				// Deny closing the window. Instead, when the user tries to close the window, ask the app to quit.
				target: globalApplicationWindow.nativeWindow
				eventType: QEvent.Close
				//We delay the destruction to prevent a crash in QtWebKit if we close
				//Graphics UI immediately after opening the investigation perspective. The crash happens
				//when the Map2DUI element is present in a window.
				onEvent: {
					accepted = false;
					main.quit()
				}
			}

			WindowGLViewport { // Enable GL viewport in the window.
				id: globalWindowGLViewport
				shareWidget: globalSandbox3dEngine.shareWidget
			}

			// Main Menu
			Desktop.MenuBar {
				id: globalMenuBar

				Desktop.Menu {
					id: fileMenu
					text: qsTr("&File")
					OmniQml.MenuItem { text: qsTr("Exit"); shortcut: "Ctrl+Q"; onTriggered: quit() }
				}

				OmniQml.Menu {
					id: viewMenu
					text: qsTr("&View")
					enabled: healthManagement.healthy

					OmniQml.MenuItem { id: actionShowFreeTextSearch; text: qsTr("Finder"); shortcut: "Ctrl+F"; checkable: true; checked: searchPanelStateGroup.state === "freetext"; onTriggered: { searchPanelStateGroup.state = "freetext"; freeTextSearchPanel.giveFocus(); } }
					//OmniQml.MenuItem { id: actionShowEvents; text: qsTr("Alarms Search"); checkable: true; checked: searchPanelStateGroup.state === "alarms"; onTriggered: searchPanelStateGroup.state  = (searchPanelStateGroup.state === "alarms")? "disabled" : "alarms" }
					//OmniQml.MenuItem { id: actionShowAlarm; text: qsTr("Events Search"); checkable: true; checked: searchPanelStateGroup.state === "events"; onTriggered: searchPanelStateGroup.state  = (searchPanelStateGroup.state === "events")? "disabled" : "events" }
					//OmniQml.MenuItem { id: actionShowScheduledActivities; text: qsTr("Scheduled Activities Search"); checkable: true; checked: searchPanelStateGroup.state === "scheduled_activities"; onTriggered: searchPanelStateGroup.state = (searchPanelStateGroup.state === "scheduled_activities") ? "disabled" : "scheduled_activities" }
					OmniQml.MenuItem { id: actionOpenDeviceList; text: qsTr("Device List"); checkable: true; checked: deviceListPanel.visible; onTriggered: searchPanelStateGroup.state = (searchPanelStateGroup.state === "device_list") ? "disabled" : "device_list" }
					OmniQml.MenuItem { id: actionShowPerspectiveList; text: qsTr("Perspective List"); shortcut: "Ctrl+P"; checkable: true; checked: true; }
					OmniQml.MenuItem { id: actionShowTimeline; text: qsTr("Timeline"); checkable: true; checked: globalTimeline.visible; onTriggered: globalTimeline.visible = !globalTimeline.visible; }
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { id: actionShowProjections; text: qsTr("Projections in 3D View"); checkable: true; checked: true; configurationSetting: "projections_visible" }
					OmniQml.MenuItem { id: actionShowPlacemarkIcons; text: qsTr("Placemark Icons"); checkable: true; checked: true; configurationSetting: "placemark_icons_visible" }
					OmniQml.MenuItem { id: actionShowAlarmIcons; text: qsTr("Alarm and Event Icons"); checkable: true; checked: true; configurationSetting: "alarm_icons_visible" }
					OmniQml.Menu {
						id: nameDisplay

						property QtObject objectNameDisplayGroup: OmniUI.ActionGroup { objects: [actionShowNamesAlways, actionShowNamesOnMouseOver, actionShowNamesOnSelection, actionShowNamesNever] }

						text: qsTr("Object Name Display")

						OmniQml.MenuItem { id: actionShowNamesAlways; text: qsTr("Always"); checkable: true; configurationSetting: "object_names_visible_always"}
						OmniQml.MenuItem { id: actionShowNamesOnMouseOver; text: qsTr("On Mouse-Over"); checkable: true; checked: true; configurationSetting: "object_names_visible_on_mouse_hover"}
						OmniQml.MenuItem { id: actionShowNamesOnSelection; text: qsTr("On Selection"); checkable: true; configurationSetting: "object_names_visible_on_selection"}
						OmniQml.MenuItem { id: actionShowNamesNever; text: qsTr("Never"); checkable: true; configurationSetting: "object_names_visible_never"}
					}

					Desktop.Menu {
						text: qsTr("Placemark Indicator Size")
						OmniQml.MenuItem { id: actionResetPlacemarkScale; text: qsTr("Reset to Default"); onTriggered: configuration.resetPlacemarkIndicatorScale() }
						OmniQml.MenuSeparator {}
						OmniQml.MenuItem { id: actionIncreasePlacemarkScale; text: qsTr("Increase"); onTriggered: configuration.increasePlacemarkIndicatorScale() }
						OmniQml.MenuItem { id: actionDecreasePlacemarkScale; text: qsTr("Decrease"); onTriggered: configuration.decreasePlacemarkIndicatorScale() }
					}
					OmniQml.MenuItem { id: actionGroupOverlappingIconsIn3D; text: qsTr("Group Overlapping Icons"); checkable: true; checked: true; configurationSetting: "enable_3d_icon_decluttering" }
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { id: actionForceOffAngleProjections; text: qsTr("Video Fusion for Off-Angle Cameras"); checkable: true; configurationSetting: "force_off_angle_camera_projections" }
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { id: actionCamerasAreTheirOwnViewpoints; text: qsTr("Camera View on Selection"); checkable: true; configurationSetting: "cameras_are_their_own_viewpoints" }
					OmniQml.MenuItem { id: actionShowSummaryOnMap; text: qsTr("Summary on Map Shortcut"); checkable: true; checked: true; configurationSetting: "showSummaryOnMap" }
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { id: actionShowEmptyQueries; text: qsTr("Show Empty Queries in Dashboard"); checkable: true; checked: false; configurationSetting: "show_empty_queries"}
				}

				OmniQml.Menu {
					text: qsTr("&Navigation")
					enabled: healthManagement.healthy
					OmniQml.MenuItem { id: actionGoHome; text: qsTr("Home"); shortcut: "Home" } // Components bind themselves to this.
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { id: actionSelectRelevantCameras; text: qsTr("Display Nearby Cameras"); shortcut: "Ctrl+E" }
					OmniQml.MenuItem { id: actionClearAllCameras; text: qsTr("Clear All Cameras"); shortcut: "Ctrl+Shift+E" }
					OmniQml.MenuItem { id: automaticCameraSelectionAction; text: qsTr("Camera selection based on map position"); checkable: true; checked: false; shortcut: "Ctrl+Shift+S"; configurationSetting: "automatic_camera_selection" }

					// Camera Strategy Selection is decommissionned. Replaced by multifactorial approach. See issue #10088
					/*Desktop.Menu {
						id: menuCameraSelectionStrategy
						text: qsTr("Nearby Camera Selection Strategy")

						OmniQml.MenuItem { id: actionStrategyObserverViewpoint; text: qsTr("Around Observer Viewpoint"); checkable: true; checked: false }
						OmniQml.MenuItem { id: actionStrategyObserverFeet; text: qsTr("Around Observer Feet"); checkable: true; checked: false }
						OmniQml.MenuItem { id: actionStrategyScreenCenter; text: qsTr("Around Screen Center"); checkable: true; checked: true }
						property QtObject cameraSelectionStrategyGroup: OmniUI.ActionGroup { objects: [actionStrategyObserverViewpoint, actionStrategyObserverFeet, actionStrategyScreenCenter] }
					}*/
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { id: actionEnableShortcutPerspectives; text: qsTr("Open new perspectives when activating shortcuts"); checkable: true; checked: false; configurationSetting: "action_enable_shortcut_perspective" }

					// FastTrack is decommissionned.
					//OmniQml.MenuSeparator {}
					//				OmniQml.MenuItem { id: actionAutomaticFastTrackNavigation; checkable: true; checked: false; text: qsTr("Automatic FastTrack Navigation "); configurationSetting: "automatic_navigation" }
					//				OmniQml.MenuItem { id: actionFastTrackView; checkable: true; checked: false; text: qsTr("FastTrack View"); configurationSetting: "fasttrack_view_enabled" }
					//				OmniQml.MenuItem { id: actionFastTrackIn3D; checkable: true; checked: false; text: qsTr("FastTrack in 3D"); configurationSetting: "fasttrack_in_3d" }


					OmniQml.MenuSeparator {}
					GuardTourMenu {
						id: globalGuardTourMenu
						text: qsTr("&Guard Tour")
						guardTours: main.world && main.world.guardToursContainer.objects
						enabled: !!globalPerspectiveManager.currentPerspective &&
								 !!globalPerspectiveManager.currentPerspective.context &&
								 !!globalPerspectiveManager.currentPerspective.context.layout &&
								 !!globalPerspectiveManager.currentPerspective.context.layout.guardTourPanel

					}
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem {
						id: actionLaunchProcedureEditor;
						text: qsTr("&Open Procedure Editor");
						shortcut: "Ctrl+Shift+P"
						enabled: healthManagement.healthy && (globalPermissionsManager.sopsManagementPermission.allowed || globalPermissionsManager.procedureOverrideManagementPermission.allowed)
						onTriggered: globalProcedureEditorController.launchProcedureEditor(null)
					}
				}

				Desktop.Menu {
					text: qsTr("&Help")
					property Component _c: Component {
						id: aboutDialogComponent
						OmniUI.AboutDialog {
							siteName: globalSiteRegistryCache.currentSiteData? globalSiteRegistryCache.currentSiteData.name : ""
							serverVersion: {
								var text = "";
								var versions = machineServiceFetcher.serverVersions;
								for (var key in versions) {
									if (text != "")
										text += ",<br/>\n";
									text += key;
									if (versions[key] > 1)
										text += " (" + versions[key] + ")";
								}
								return text != "" ? text : qsTr("No servers found");
							}
							licensedTo : licenseFetcher.issuedTo;
							expiresIn : licenseFetcher.expiresIn;
							expiryDate : licenseFetcher.expiryDate;
							expired : licenseFetcher.expired;
						}
					}

					OmniQml.MenuItem { text: qsTr("About"); onTriggered: { var dialog = aboutDialogComponent.createObject(null); dialog.exec(); dialog.destroy(); } }
				}

				OmniQml.Menu {
					id: debugMenu
					text: qsTr("Debu&g")
					visible: showDebugMenuAction.checked || argumentParser.contains("debug")

					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { id: actionShowCurrentSite; text: "Show Current Site"; checkable: true; checked: false; configurationSetting: "show_current_site"}
					OmniQml.MenuItem { id: actionShowCameraOrientationIcons; text: qsTr("Show Camera Orientation Icons"); checkable: true; checked: false; configurationSetting: "show_camera_orientation_icons" }
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { id: actionShowFeedPermissionDetails; enabled: debugMenu.visible; text: qsTr("Show Feed Permission Details"); checkable: true }
					OmniQml.MenuItem { id: actionBufferStatusIndicatorVisible; enabled: debugMenu.visible; text: qsTr("Show Buffer Status Indicator"); checkable: true; configurationSetting: "bufferStatusIndicatorVisible" }
					OmniQml.MenuItem { text: qsTr("Force Crash Application"); onTriggered: logger.forceCrash(); }
					OmniQml.MenuItem { id: actionSystemMetrics; text: qsTr("System Metrics"); checkable: true; checked: false; configurationSetting: "system_metrics_enabled" }
					OmniQml.MenuItem {
						id: actionCloseAllAlarms;
						text: qsTr("Close All Alarms");
						onTriggered: {
							var min = 0;
							var max = 7 /*days*/ * 24 /*hours*/ * 60 /*min*/ * 60 /*secs*/;
							var errorValue = -1;
							var minutes = Utilities.getInt(qsTr("Close opened alarms"), qsTr("Older than X minutes: "), min, max, errorValue);

							if(minutes !== -1) {
								if (Utilities.confirm(qsTr("Warning"), qsTr("This operation is irreversible.  Are you sure you want to do it anyway?"))) {
									batchAlarmCloser.closeAlarmsOlderThan(minutes * 60);	// Time in seconds!
								}
							}
						}
					}
					OmniQml.MenuItem { id: actionPlayPause; text: qsTr("Play / Pause"); checkable: true; checked: true; shortcut: "Ctrl+Space" }
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { text: qsTr("Export Visible Query to Clipboard"); enabled: globalSearchContainer.visible; onTriggered: { globalSearchContainer.exportToClipboard(); queryExportTooltip.activate()} }
					OmniQml.MenuItem { text: qsTr("Import Visible Query from Clipboard"); onTriggered: { globalSearchContainer.importFromClipboard(); } }
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { id: actionBingLicenseKey;
						text: qsTr("Configure Bing License");
						property string licenseKey: configuration.value("BingMapLicenseKey", "")
						onTriggered: {
							var key = Utilities.getText(qsTr("Bing license key"), qsTr("Insert your Bing License Key (Empty to clear)"), licenseKey, "null")

							if (key !== "null") { // Error value to account for cancel
								licenseKey = key;
								configuration.setValue("BingMapLicenseKey", key);
							}
						}
					}
					OmniQml.MenuSeparator {}
					Desktop.Menu {
						id: menuAlarm
						text: qsTr("&Sound")

						OmniQml.MenuItem { text: qsTr("Enabled"); onTriggered: globalSoundPlayer.enabled = !globalSoundPlayer.enabled; checkable: true; checked: globalSoundPlayer.enabled; }
						OmniQml.MenuItem {
							id: actionTriggerAlarmWhenAwaySound;
							text: qsTr("Trigger alarm (when away) sound");
							enabled: !globalSoundPlayer.looping // don't override looping sound with a debug sound
							onTriggered: {
								var alarmWhenAwaySound = globalActiveConfiguration && globalActiveConfiguration.alarmWhenAwaySound || OmniUI.SoundBank.Alarm;
								if (alarmWhenAwaySound === OmniUI.SoundBank.Default) { alarmWhenAwaySound = OmniUI.SoundBank.Alarm; }
								if (alarmWhenAwaySound !== OmniUI.SoundBank.None) { globalSoundPlayer.playSound(alarmWhenAwaySound, false); }
							}
						}
						OmniQml.MenuItem {
							id: actionTriggerAlarmWhenActiveSound;
							text: qsTr("Trigger alarm (when active) sound");
							enabled: !globalSoundPlayer.looping // don't override looping sound with a debug sound
							onTriggered: {
								var alarmWhenActiveSound = globalActiveConfiguration && globalActiveConfiguration.alarmWhenActiveSound || OmniUI.SoundBank.Notification;
								if (alarmWhenActiveSound === OmniUI.SoundBank.Default) { alarmWhenActiveSound = OmniUI.SoundBank.Notification; }
								if (alarmWhenActiveSound !== OmniUI.SoundBank.None) { globalSoundPlayer.playSound(alarmWhenActiveSound, false); }
							}
						}
						OmniQml.MenuItem {
							id: actionTriggerRMSSound;
							text: qsTr("Trigger RMS sound");
							enabled: !globalSoundPlayer.looping // don't override looping sound with a debug sound
							onTriggered: {
								var rmsSound = globalActiveConfiguration && globalActiveConfiguration.rmsSound || OmniUI.SoundBank.RMSEnabled;
								if (rmsSound === OmniUI.SoundBank.Default) { rmscoSound = OmniUI.SoundBank.RMSEnabled; }
								if (rmsSound !== OmniUI.SoundBank.None) { globalSoundPlayer.playSound(rmsSound, false); }
							}
						}
					}
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { text: qsTr("Force Garbage Collection"); onTriggered: gc(); shortcut: "Ctrl+T" }
					OmniQml.MenuSeparator {}
					OmniQml.MenuItem { id: showLayoutList; text: qsTr("Show Layout List"); checkable: true; }
					OmniQml.MenuItem { text: qsTr("Full Screen"); shortcut: "F11"; checkable: true;
						checked: globalApplicationWindow.fullScreen;
						onTriggered: globalApplicationWindow.extender.setFullScreen(!globalApplicationWindow.fullScreen);
					}
					OmniQml.MenuItem { id: actionSelectRandomCameras; text: qsTr("Display Random Cameras"); shortcut: "Ctrl+R" }
					OmniQml.MenuItem { id: actionExportRelevantCamerasMetricDataToCSV; text: qsTr("Export Relevant Camera Metric data to CSV"); checkable: true; checked: false;  }
					OmniQml.MenuSeparator {}

					OmniQml.MenuItem { id: showDebugMenuAction; text: qsTr("Hide Debu&g Menu"); checkable: true; shortcut: "Ctrl+Shift+G" }
				}
			}

			// Main Application window.
			Rectangle {
				id: applicationWindowContent
				anchors.fill: parent
				color: StyledPalette.windowBackground

				// Displayed UI during CC InitializationSystem
				// --------------------------------------------
				InitializationSystem.InitializationUI {
					id: initializationUi

					width: 600
					y: -height - 1
					anchors.horizontalCenter: parent.horizontalCenter

					sequence: initializationSequenceComponent.createObject(main)

					property QtObject argumentParser: argumentParser

					Component {
						id: initializationSequenceComponent

						GraphicsUIInitializationSequence {
							autoStart: true
							localServices: _private.localServices
							failsafeEventSink: failsafeEventSinkDecorator
							healthAggregator: _private.localServices.healthStatusAggregator
							argumentParser: initializationUi.argumentParser

							onCompleted: {
								logger.debug("GraphicsUI", "Initialization sequence completed");
								destroy();
							}
						}
					}
				}
				// initializationUi
				Unlimited_Security.PlacemarkIconProvider {
					id: globalPlacemarkIconProvider
					ictDeviceSynchronizer: globalIctDeviceSynchronizer
					accessControlStatusManager: globalAccessControlStatusManager
				}

				FlexiblePerspectiveContextBuilder {
					id: globalFlexiblePerspectiveContextBuilder
					localServices: _private.localServices
					remoteServices: _private.remoteServices

					isCMS: siteTypeInfoMembers.isCMSSite

					packagesManager: packagesManager
				}

				MajorAlarmIndicatorOverlay {
					id: newAlarmIndicator
					z: 1000 /* above everything */
					visible: false

					Repeater {
						model: StableObjectListModel {
							objectList: {
								var perspectiveButtons = [];
								for (var i = 0; i < localPerspectivesColumn.children.length; ++i)
									perspectiveButtons.push(localPerspectivesColumn.children[i]);
								for (var i = 0; i < remotePerspectivesColumn.children.length; ++i)
									perspectiveButtons.push(remotePerspectivesColumn.children[i]);
								return perspectiveButtons;
							}
						}
						Item {
							id: flashingManagerWatcher
							property QtObject perspectiveButton: modelData
							property QtObject perspective: perspectiveButton.perspective || null
							property QtObject flashingManager: perspective && perspective.context && perspective.context.alarmSearchSinkFlashingManager || null
							property QtObject queryPanelConfiguration
							queryPanelConfiguration: {
								var profile = flashingManagerWatcher.perspective && flashingManagerWatcher.perspective.profile || null;
								if (!profile) return null;

								var configs = profile.elementConfigurationsData;
								if (!configs || configs.length === 0) return null;

								for (var i = 0; i < configs.length; ++i) {
									var elementConfig = configs[i];
									if (elementConfig.name === "queryPanel") {
										return elementConfig;
									}
								}

								return null;
							}
							property bool fullscreenFlash: !!queryPanelConfiguration && queryPanelConfiguration.flashingMode === Deployment.FlashingMode.Full
							Connections {
								target: flashingManagerWatcher.flashingManager
								onFlashingRequestedChanged: {
									if (flashingManagerWatcher.flashingManager.flashingRequested) {
										if (flashingManagerWatcher.fullscreenFlash && flashingManagerWatcher.perspectiveButton.visible) newAlarmIndicator.visible = true;
										if (!awayFromKeyboardEventFilter.hasFocus || awayFromKeyboardEventFilter.isAwayFromKeyboard) {
											var alarmWhenAwaySound = globalActiveConfiguration && globalActiveConfiguration.alarmWhenAwaySound || OmniUI.SoundBank.Alarm;
											if (alarmWhenAwaySound === OmniUI.SoundBank.Default) { alarmWhenAwaySound = OmniUI.SoundBank.Alarm; }
											if (alarmWhenAwaySound !== OmniUI.SoundBank.None) { globalSoundPlayer.playSound(alarmWhenAwaySound, true); }
										} else if (!globalSoundPlayer.looping) { // don't override looping sound with a one shot sound
											var alarmWhenActiveSound = globalActiveConfiguration && globalActiveConfiguration.alarmWhenActiveSound || OmniUI.SoundBank.Notification;
											if (alarmWhenActiveSound === OmniUI.SoundBank.Default) { alarmWhenActiveSound = OmniUI.SoundBank.Notification; }
											if (alarmWhenActiveSound !== OmniUI.SoundBank.None) { globalSoundPlayer.playSound(alarmWhenActiveSound, false); }
										}
									} else {
										//	flashingRequested is false need to remove flashing
										newAlarmIndicator.visible = false;
										globalSoundPlayer.stop();
									}
								}
							}
						}
					}

					MouseArea {
						anchors.fill: parent
						acceptedButtons: Qt.AllButtons
						onPressed: {
							newAlarmIndicator.visible = false;
							mouse.accepted = false;
						}
					}
					Connections {
						target: globalApplicationWindow
						onActiveChanged: if (globalApplicationWindow.active) newAlarmIndicator.visible = false
					}
				}

				Row {
					id: leftPanesContainer
					anchors { left: parent.left; top: parent.top; bottom: bottomBarContainer.top }
					z: 100 // Above the main container, below the bottom bar.

					FocusScope {
						id: perspectiveTabsPane
						anchors { top: parent.top; topMargin: -1; bottom: parent.bottom }
						width: 160
						visible: actionShowPerspectiveList.checked

						property int containerHeight: newTaskButton.y - finderButton.y

						// Manages the contextual menu for perspective buttons
						// ---------------------------------------------------
						MouseArea {
							anchors.fill: parent
							acceptedButtons: Qt.RightButton
							onPressed: {
								if (mouse.button === Qt.RightButton) {
									var pos = leftPanesContainer.mapToItem(null, mouse.x, mouse.y);
									leftPanesContextMenu.showPopup(pos.x, pos.y);
								}
							}

							OmniQml.Menu {
								id: leftPanesContextMenu

								OmniQml.MenuItem {
									text: globalPerspectiveManager.detachedPerspectiveCount > 0 ? qsTr("Close %1 perspective window(s)").arg(globalPerspectiveManager.detachedPerspectiveCount) : qsTr("No perspective windows to close")
									onTriggered: globalPerspectiveManager.closeAllPerspectiveWindows()
									enabled: globalPerspectiveManager.detachedPerspectiveCount > 0
								}
							}
						}
						// ---------------------------------------------------


						// Finder Tool
						// ---------------------------------------------------
						Rectangle {
							id: finderButton

							anchors { left: parent.left; right: parent.right; top: parent.top }
							height: 32
							color: searchPanelStateGroup.state === "freetext" ? "#fcfafb" : "transparent"

							property string textColor: (searchPanelStateGroup.state === "freetext" || finderMouseArea.containsMouse) ? StyledPalette.highlight : "gray"


							//Search textbox appearing on top of prespective buttons
							StyledText {
								anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 8; verticalCenter: parent.verticalCenter }
								color: finderButton.textColor
								text: qsTr("Find ...")
							}

							StyledIcon {
								anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 8; verticalCenter: parent.verticalCenter }
								color: finderButton.textColor
								font.pixelSize: 16
								font.family: "FontAwesome"
								icon: "Search"
							}

							MouseArea {
								id: finderMouseArea
								anchors.fill: parent
								hoverEnabled: true
								onClicked: { searchPanelStateGroup.state = "freetext"; freeTextSearchPanel.giveFocus(); }
							}
						}
						// ---------------------------------------------------


						// Warning panel indicating changes applied to perspective definitions
						// by the Content Administration Tool.
						//-------------------------------------------------------------------------
						Rectangle {
							id: profilesChangedIndicator

							anchors { left: parent.left; right: parent.right; top: finderButton.bottom }
							visible: updatedPerspectivesContainer.hasChanges
							height: visible ? 32 : 0

							color: "lightYellow"

							StyledText {
								anchors { left: parent.left; right: refreshPerspectivesButton.left; margins: 10; verticalCenter: parent.verticalCenter }
								text: qsTr("Updates Available")
							}

							StyledRectangleButton {
								id: refreshPerspectivesButton
								anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
								height: width
								icon: "Refresh"
								onClicked:  {
									perspectivesColumn.alreadyInitialized = false;
									perspectivesColumn.applyUpdatedPerspectiveProfiles()
								}
							}
						}
						//-------------------------------------------------------------------------

						// The Perspective button column has a splitter button allowing to
						// navigate easily between families of perspective buttons (Local vs
						// remote perspective buttons).
						// -----------------------------------------------------------------------
						OmniQml.SplitterColumn {
							id: perspectivesColumn
							anchors { left: parent.left; right: parent.right; top: profilesChangedIndicator.bottom; bottom: newTaskButton.top }

							handleBackground: OmniQml.SplitterHandle { size: 10; visible: remotePerspectivesContainer.visible; normalColor:"#bfbfbf"; hoveredColor: "#606060"; verticalScroll: true }

							property QtObject perspectivesModel: ObjectSortFilterProxyModel {
								filter: ObjectIntPropertyFilter { property: "state"; value: GenericObjectDataStore.StoredObjectState.Enabled; operatorType: ObjectIntPropertyFilter.Equal }
								UniqueSharedObjectContainer { id: perspectivesContainer }
							}
							property QtObject updatedPerspectivesContainer: UniqueSharedObjectContainer {
								id: updatedPerspectivesContainer
								property bool hasChanges: false
							}
							property QtObject currentPerspectivesCache: Deployment.PerspectiveProfileCache {
								bucket: "/profiles/perspectives"
								ignoreDraft: true
								InterfaceBinding on datastore { value: _private.localServices.genericObjectDatastore }
								onSequenceNumberChanged: perspectivesColumn.updatePerspectiveProfiles()
							}
							property QtObject currentGroupProfilesCache: Deployment.GroupProfileCache {
								bucket: "/profiles/groups"
								ignoreDraft: true
								InterfaceBinding on datastore { value: _private.localServices.genericObjectDatastore }
								onSequenceNumberChanged: perspectivesColumn.updatePerspectiveProfiles()
							}
							property bool customPerspectivesInitialized: currentGroupProfilesCache.initialUpdateCompleted && currentPerspectivesCache.initialUpdateCompleted && !!globalUserRegistryCache.callingUser
							onCustomPerspectivesInitializedChanged: if (customPerspectivesInitialized) { updatePerspectiveProfiles(); applyUpdatedPerspectiveProfiles() }

							property bool alreadyInitialzed: false;

							// Makes a list of perspectives available to current user
							//--------------------------------------------------------------
							function updatePerspectiveProfiles() {
								if (alreadyInitialzed || !customPerspectivesInitialized) return;
								var allUsersGroupProfileId = TypeHelper.stringToUuid("{7d11c1c7-0275-4a92-99d8-94680f4b82c0}");
								var userGroups = globalUserRegistryCache.callingUser.groupsData;
								var perspectiveIds = [];
								var perspectiveIdMap = {};

								var groupIds = userGroups.map(function(group) { return group._idData._id; });
								groupIds = groupIds.concat(allUsersGroupProfileId);

								for (var groupIndex = 0; groupIndex < groupIds.length; ++groupIndex) {
									var groupProfile = currentGroupProfilesCache.findById(groupIds[groupIndex]);
									if (!groupProfile) continue;
									var perspectiveProfiles = TypeHelper.uuidVectorToUuidList(groupProfile.perspectiveProfiles);
									for (var perspectiveProfileIndex = 0; perspectiveProfileIndex < perspectiveProfiles.length; ++perspectiveProfileIndex) {
										var profileId = perspectiveProfiles[perspectiveProfileIndex];
										if (!perspectiveIdMap.hasOwnProperty(TypeHelper.uuidToString(profileId))) {
											perspectiveIdMap[TypeHelper.uuidToString(profileId)] = true;
											perspectiveIds.push(profileId);
										}
									}
								}

								updatedPerspectivesContainer.objectList = perspectiveIds.map(function(id) { return currentPerspectivesCache.findById(id); });
								updatedPerspectivesContainer.hasChanges = true;
							}
							//--------------------------------------------------------------

							// Applies the updated perspectives...
							function applyUpdatedPerspectiveProfiles() {
								if (alreadyInitialzed) return;
								perspectivesContainer.objectList = updatedPerspectivesContainer.objectList;
								updatedPerspectivesContainer.clear();
								updatedPerspectivesContainer.hasChanges = false;
								if (!currentPerspective) globalPerspectiveManager.openDefaultPerspective();

								alreadyInitialzed = true;
							}


							// Display Local Perspective Buttons
							// ------------------------------------------------------
							StyledFlickable {
								id: localPerspectivesContainer
								clip: true
								interactive: isScrollBarVisible
								contentHeight: localPerspectivesColumn.height
								scrollBarBGColor: "transparent"

								// Splitter properties, do not remove
								property real minimumHeight: 64
								property real percentageHeight: visible ? 50 : 100

								Column {
									id: localPerspectivesColumn
									anchors { left: parent.left; top: parent.top; right: parent.right }

									onHeightChanged: null //Do not remove or else contentHeight won't update properly.

									// Site button
									PerspectiveTabButton {
										title: globalSiteRegistryCache.currentSiteData? globalSiteRegistryCache.currentSiteData.name : "Unknown Site"
										visible: parent.width > 0 && actionShowCurrentSite.checked
										showCaret: false  // remove caret when displaying site.
									}
									//----------------------------------------------


									// Extract the available LOCAL perspectives from the generic datastore
									Repeater {
										model: {
												return localCustomPerspectivesModel.ItemModelExtender.count > 0 ? localCustomPerspectivesModel : defaultLocalCustomPerspectiveModel;
										}

										property QtObject localCustomPerspectivesModel: ObjectSortFilterProxyModel {
											filter: ObjectBoolPropertyFilter { property: "rmsPerspective"; keepWhen: false }
											sourceModel: perspectivesColumn.perspectivesModel
										}

										property QtObject defaultLocalCustomPerspectiveModel: ObjectContainerModel {
											ObjectContainer {
												Deployment.PerspectiveProfile {
													displayName: qsTr("Monitoring")
													rmsPerspective: false
													initialLayoutType: "investigation"
												}
											}
										}


										// For each perspectiveProfile object found, display the appropriate tab button
										CustomProfilePerspectiveTabButton {
											id: customPerspective

											property QtObject profile: modelData

											property QtObject flexPerspective:  FlexiblePerspective {
												contextComponent: globalFlexiblePerspectiveContextBuilder.localPerspectiveBinding
												type: "custom"
												initialLayoutType: {return profile && profile.initialLayoutType	}
												profile: customPerspective.profile
												name: profile.displayName
											}



											property QtObject webPerspective: WebPagePerspective {
												//contextComponent: globalFlexiblePerspectiveContextBuilder.localPerspectiveBinding
												//type: "webPage"
												profile: customPerspective.profile
												//initialLayoutType: profile && profile.initialLayoutType
												name: profile.displayName

												//configuration: webPanelConfiguration
												property bool timelineWasVisible: false
												property bool selectionWasVisible: false
												property string searchContainerStateWas: "disabled"

												onActiveChanged: {
													if (active) {
														timelineWasVisible = timelineContainer.visible
														timelineContainer.visible = false
														searchContainerStateWas = searchPanelStateGroup.state
														searchPanelStateGroup.state = "disabled"
													} else {
														timelineContainer.visible = timelineWasVisible
														searchPanelStateGroup.state = searchContainerStateWas
													}
												}
											}

											onClicked: if (mouse.button === Qt.LeftButton) globalPerspectiveManager.openPerspective(perspective)

											// When detaching web pages, CC looses responsiveness and tabs are disabled.
											// Therefore, we remove the capacity of detaching the webpageperspectives.
											allowDetach: (profile.category !== "custom_web_layout")
											perspective: (profile.category !== "custom_web_layout") ? flexPerspective : webPerspective;
										}
									}

									// Display the current Alarm perspective(s).
									Repeater {
										model: ObjectContainerModel { objectContainer: globalAlarmPerspectiveManager.localAlarmPerspectives }

										AlarmPerspectiveTabButton {
											anchors { left: parent && parent.left || undefined; right: parent && parent.right || undefined }
											perspective: object
											visible: !perspective.window
										}
									}

									// Display the current Investigation from a Video Matrix Camera perspective(s).
									Repeater {
										model: ObjectContainerModel { objectContainer: globalInvestigationPerspectiveManager.investigationPerspectives }

										PerspectiveTabButton {
											id: cameraTabButton

											title: qsTr("Camera Investigation")
											firstSubtitle: perspective.name
											perspective: object
											anchors { left: parent && parent.left || undefined; right: parent && parent.right || undefined }
											visible: !perspective.window
											acceptedButtons: Qt.AllButtons
											onClicked: {
												if (mouse.button === Qt.LeftButton) globalPerspectiveManager.openPerspective(perspective)
												else if (mouse.button === Qt.MidButton) globalInvestigationPerspectiveManager.closePerspective(perspective)
											}
											OmniQml.MenuItem { id: closeCameraMenuItem; text: qsTr("Close"); onTriggered: globalInvestigationPerspectiveManager.closePerspective(perspective) }
											Component.onCompleted: cameraTabButton.contextMenu.addCompleteMenuItem(closeCameraMenuItem);
										}
									}

									// Display the current Perspective from a resource perspective(s).
									Repeater {
										model: ObjectContainerModel { objectContainer: globalResourcePerspectiveManager.resourcePerspectives }

										PerspectiveTabButton {
											id: resourceTabButton

											title: qsTr("Follow Resource")
											firstSubtitle: perspective.name
											perspective: object
											anchors { left: parent && parent.left || undefined; right: parent && parent.right || undefined }
											visible: !perspective.window
											acceptedButtons: Qt.AllButtons
											onClicked: {
												if (mouse.button === Qt.LeftButton) globalPerspectiveManager.openPerspective(perspective)
												else if (mouse.button === Qt.MidButton) globalResourcePerspectiveManager.closePerspective(perspective)
											}
											OmniQml.MenuItem { id: closeResourceMenuItem; text: qsTr("Close"); onTriggered: globalResourcePerspectiveManager.closePerspective(perspective) }
											Component.onCompleted: resourceTabButton.contextMenu.addCompleteMenuItem(closeResourceMenuItem);
										}
									}

									// Display perspective shortcuts.
									// Ref: issue 9621. (Dept of state demo).
									// TODO: To be investigated why it was merged in dev.
									Repeater {
										model: ObjectContainerModel { objectContainer: globalShortcutPerspectiveManager.shortcutPerspectives }

										PerspectiveTabButton {
											id: locationTabButton

											title: perspective.displayName
											perspective: object
											acceptedButtons: Qt.AllButtons
											onClicked: {
												if (mouse.button === Qt.LeftButton) globalPerspectiveManager.openPerspective(perspective)
												else if (mouse.button === Qt.MidButton) globalShortcutPerspectiveManager.closeShortcutPerspective(perspective)
											}
											visible: !perspective.window

											OmniQml.MenuItem { id: closeMenuItem; text: qsTr("Close"); onTriggered: globalShortcutPerspectiveManager.closeShortcutPerspective(perspective) }

											Component.onCompleted: locationTabButton.contextMenu.addCompleteMenuItem(closeMenuItem);
										}
									}
								}
							}
							// ------------------------------------------------------

							// Display Remote Perspective Buttons.
							// -------------------------------------------------------
							StyledFlickable {
								id: remotePerspectivesContainer
								contentHeight: remotePerspectivesColumn.height
								interactive: isScrollBarVisible
								clip: true
								scrollBarBGColor: "transparent"

								// Splitter properties, do not remove
								property real minimumHeight: 64
								property bool expanding: true

								visible: remoteMonitoringAccessTracker.accessEnabled && remoteMonitoringAccessTracker.monitoredSitesData.length > 0
								onVisibleChanged: height = parseInt(parent.height / 2)

								function transferRmsScope(perspective) {
									var scopes = _private.remoteServices.getPublishers();
									for (var i = 0; i < scopes.length; ++i) {
										var newScope = scopePublishComponent.createObject(perspective, { key: scopes[i].key, sourceScope: scopes[i] });
									}
								}

								Component {
									id: scopePublishComponent
									ScopePublish {
										value: sourceScope.value
										property QtObject sourceScope
									}
								}

								Column {
									id: remotePerspectivesColumn
									anchors { left: parent.left; right: parent.right }

									Repeater {
										model: {
											if (!remotePerspectivesContainer.visible) return 0;
											else if (remoteCustomPerspectivesModel.ItemModelExtender.count > 0) return remoteCustomPerspectivesModel;
											else return defaultRemoteCustomPerspectiveModel;
										}

										property QtObject remoteCustomPerspectivesModel: ObjectSortFilterProxyModel {
											filter: ObjectBoolPropertyFilter { property: "rmsPerspective"; keepWhen: true }
											sourceModel: perspectivesColumn.perspectivesModel
										}

										property QtObject defaultRemoteCustomPerspectiveModel: ObjectContainerModel {
											ObjectContainer {
												Deployment.PerspectiveProfile {
													displayName: qsTr("Remote Monitoring")
													rmsPerspective: true
													initialLayoutType: "investigation"
												}
											}
										}

										CustomProfilePerspectiveTabButton {
											id: customRemotePerspectiveButton

											property QtObject profile: modelData

											onClicked: if (mouse.button === Qt.LeftButton) globalPerspectiveManager.openPerspective(perspective)
											perspective: FlexiblePerspective {
												id: customRemotePerspective
												name: profile.displayName
												contextComponent: globalFlexiblePerspectiveContextBuilder.remotePerspectiveBinding
												type: "custom"
												initialLayoutType: profile && profile.initialLayoutType
												profile: customRemotePerspectiveButton.profile
												onInitialLayoutChanged: if (initialLayout) remotePerspectivesContainer.transferRmsScope(customRemotePerspective)
											}
										}
									}

									Repeater {
										model: ObjectContainerModel { objectContainer: globalAlarmPerspectiveManager.remoteAlarmPerspectives }

										AlarmPerspectiveTabButton {
											id: remoteAlarmPerspective
											anchors { left: parent && parent.left || undefined; right: parent && parent.right || undefined }
											perspective: object
											visible: !perspective.window
											Component.onCompleted: remotePerspectivesContainer.transferRmsScope(remoteAlarmPerspective)
										}
									}
								}

								MajorAlarmIndicatorOverlay {
									anchors { fill: remotePerspectivesColumn; margins: 5 }
									border { color: "green"; width: 10 }
									visible: remoteMonitoringAccessTracker.indicateRMSaccessEnabledChange
									MouseArea {
										anchors.fill: parent
										acceptedButtons: Qt.AllButtons
										onPressed: {
											remoteMonitoringAccessTracker.indicateRMSaccessEnabledChange = false;
											mouse.accepted = false;
										}
									}
								}
							}
							// ------------------------------------------------------
						}

						// Defines the NEW button located at the bottom of the
						// Perspective button column.
						// ------------------------------------------------------------------
						StyledRectangleButton {
							id: newTaskButton
							anchors { left: parent.left; right: parent.right; bottom:logo.top; margins: 8 }
							text: qsTr("+ New")
							enabled: globalNewUserAlarmManager.ready && !!globalPerspectiveManager.currentPerspective && !!globalPerspectiveManager.currentPerspective.context && !globalPerspectiveManager.currentPerspective.context.readOnly
							onClicked: globalNewUserAlarmManager.requestNewUserAlarm()
						}
						// ------------------------------------------------------------------

						// Manages the logo displayed on the bottom left column.
						// Uses (if present) this logo: C:/GUIData/logo.png
						// ------------------------------------------------------------------
						Image {
							id: logo
							anchors { left: parent.left; right: parent.right; bottom:parent.bottom; margins: 8 }
							fillMode: Image.PreserveAspectFit
							source: "file:///C:/GUIData/logo.png"
							onStatusChanged: if(logo.status == Image.Error && source != "logo_GUI.png") source = "logo_GUI.png";
						}

						StyledBorderRectangle { anchors.fill: parent }
					}
					// ------------------------------------------------------------------

					// Reserved area for the search tool.
					Item {
						id: maximizedSearchContainer
						anchors { top: parent.top; bottom: parent.bottom }
						width: (globalSearchContainer.visible && !globalSearchContainer.detached) ? globalSearchContainer.width : 0
					}
				}

				Rectangle {
					id: mainContainer
					anchors { left: parent.left; leftMargin: leftPanesContainer.width; top: parent.top; topMargin: -1; right: parent.right; bottom: parent.bottom; bottomMargin: bottomBarContainer.height + timelineContainer.height }
					border { width: 1; color: StyledPalette.border }
					color: "transparent"

					Item {
						id: mainPerspectiveContainer
						anchors { fill: parent; leftMargin: 1; topMargin: 1; } // Leave space for the parent Rectangle's border.
						clip: true
					}
					MouseArea {
						anchors.fill: parent
						acceptedButtons: Qt.AllButtons
						id: flashingMouseArea

						property QtObject flashingManager: currentPerspective && currentPerspective.context && currentPerspective.context.alarmSearchSinkFlashingManager || null
						visible: !!flashingManager && flashingManager.indicateNewAlarm
						onPressed: {
							resetIndicateNewAlarm();
							mouse.accepted = false;
						}

						function resetIndicateNewAlarm() {
							flashingManager.indicateNewAlarm = false;
						}
					}
				}

				// Reserved area for displaying the timeline control.
				Rectangle {
					id: timelineContainer
					anchors { left: mainContainer.left; right: mainContainer.right; bottom: bottomBarContainer.top }
					border { width: 1; color: StyledPalette.border }
					color: "transparent"

					height: globalTimeline.visible ? globalTimeline.height : 0

					GraphicsUIMainTimeline {
						id: globalTimeline
						anchors { left: parent.left; top: parent.top; right: parent.right }
						visible: false

						eventSink: _private.localServices.eventSink
						siteId: siteTypeInfoMembers.siteId
						callingUser: globalUserRegistryCache.callingUser
						alarmQueryService: _private.localServices.alarmQueryService
						selectionController: globalSelectionController
						eventCache: main.currentPerspective && main.currentPerspective.context && main.currentPerspective.context.eventCache || null
						readOnly: (main.currentPerspective && main.currentPerspective.context) ? main.currentPerspective.context.readOnly : true
						timelineAlarmFetcher: globaltimelineAlarmFetcher
					}

					AlarmsUi.TimelineAlarmFetcher {
						id: globaltimelineAlarmFetcher

						timeScale: globalTimeline.timeScale
						eventCache: main.currentPerspective && main.currentPerspective.context && main.currentPerspective.context.eventCache || null

						InterfaceBinding on alarmQueryService { value:_private.localServices.alarmQueryService }
					}
				}
				// timelineContainer

				Item {
					id: bottomBarContainer
					anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
					height: 30
					z: 200 // Above the main container and the left panes container.

					MouseArea { // Notification Toasts
						anchors { right: parent.right; bottom: parent.top }
						width: 350
						height: toastsColumn.height + 9
						visible: toastsModel.ItemModelExtender.count > 0
						acceptedButtons: Qt.AllButtons
						hoverEnabled: true
						z: 1

						StyledBorderRectangle {
							anchors { fill: parent; bottomMargin: 1 }
							color: "#777"
							opacity: 0.7
						}

						ObjectSortFilterProxyModel {
							id: toastsModel
							sourceModel: globalNotificationManager.notificationsModel
							sortComparator: ObjectDateTimeComparator {
								property: "timestamp"
							}
							filter: ObjectCompositeFilter {
								matchType: ObjectCompositeFilter.MatchAll
								ObjectBoolPropertyFilter {
									property: "dismissed"
									keepWhen: false
								}
								ObjectIntPropertyFilter {
									property: "priority"
									value: 1
									operatorType: ObjectIntPropertyFilter.GreaterOrEqualThan
								}
							}
						}

						Column {
							id: toastsColumn
							y: 5
							spacing: 5
							anchors { left: parent.left; right: parent.right; margins: 5 }

							StyledBorderRectangle {
								anchors { left: parent ? parent.left : undefined; right: parent ? parent.right : undefined }
								visible: toastsModel.ItemModelExtender.count > 2
								height: visible ? 30 : 0
								color: "white"

								StyledText {
									text: qsTr("%1 Notification(s)").arg(toastsModel.ItemModelExtender.count - 2)
									anchors.centerIn: parent
								}
							}

							Notifications.NotificationToast {
								id: secondNotification
								anchors { left: parent ? parent.left : undefined; right: parent ? parent.right : undefined }
								notification: toastsModel.ItemModelExtender.count >= 2 ? toastsModel.ItemModelExtender.objectAt(1) : null
								visible: !!notification
								interactive: false
								states: State {
									when: !visible
									PropertyChanges { target: secondNotification; height: 0 }
								}
							}

							Notifications.NotificationToast {
								id: firstNotification
								anchors { left: parent ? parent.left : undefined; right: parent ? parent.right : undefined }
								notification: toastsModel.ItemModelExtender.count >= 1 ? toastsModel.ItemModelExtender.objectAt(0) : null
								visible: !!notification
								interactive: false
								states: State {
									when: !visible
									PropertyChanges { target: firstNotification; height: 0 }
								}
							}
						}
					}

					Row {
						id: leftBottomRow
						anchors { left: parent.left; top: parent.top; bottom: parent.bottom; }

						// Shows the "Perspectives" button on the bottom left side.
						 // Allows to show / hide the perspective button bar.
						// -----------------------------------------------------------------
						StyledBorderRectangle {
							id: perspectivesButtonContainer

							anchors { top: parent.top; bottom: parent.bottom }
							width: perspectiveTabsPane.visible ? perspectiveTabsPane.width : perspectivesButton.width

							Rectangle {
								anchors { left: parent.left; top: parent.top; right: parent.right; }
								height: 2
								color: StyledPalette.highlight
								visible: perspectiveTabsPane.visible
							}

							StyledTextButton {
								id: perspectivesButton
								icon: "ThLarge"
								text: qsTr("Perspectives")
								padding: 10
								anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
								onClicked: actionShowPerspectiveList.checked = !actionShowPerspectiveList.checked
							}
						}
						// -------------------------------------------------------------
						// perspectivesButtonContainer


						Item {
							id: searchZone
							anchors { top: parent.top; bottom: parent.bottom }
							width: searchButtons.width

							// Manages the "DEVICE LIST" and "SEARCH" buttons of CC.
							Row {
								id: searchButtons
								anchors { top: parent.top; bottom: parent.bottom }

							   Repeater {
								   id: searchButtonRepeater
									property string selectedSearch: searchComboBox && searchComboBox.selectedPanel ? searchComboBox.selectedPanel : "events"

									model: [
										{ displayName: qsTr("Device List"), icon: "Sitemap", type: "device_list", available: true },
										{ displayName: qsTr("Search"), icon: "Search", type: selectedSearch, available: true }
									]
									delegate: StyledBorderRectangle {
										anchors { top: parent ? parent.top : undefined; bottom: parent ? parent.bottom : undefined }
										width: searchLabel.width
										visible: modelData.available
										property bool active: globalSearchContainer.visible && searchPanelStateGroup.state === modelData.type

										StyledTextButton {
											id: searchLabel
											text: modelData.displayName
											icon: modelData.icon
											padding: 10
											anchors { top: parent.top; bottom: parent.bottom }
											onClicked: searchPanelStateGroup.state  = (searchPanelStateGroup.state === modelData.type) ? "disabled" : modelData.type
										}

										Rectangle {
											anchors { left: parent.left; top: parent.top; right: parent.right; }
											height: 2
											color: StyledPalette.highlight
											visible: active
										}
									}
							   }
							   // searchButtonRepeater
							}
							// searchButtons

							// UI element providing search tools
							//-----------------------------------------------------
							StyledPopoutContainer {
								id: globalSearchContainer
								title: qsTr("Search")
								key: qsTr("Search")

								visible: false
								onCloseRequested: searchPanelStateGroup.state = "disabled"

								parent: maximizedSearchContainer
								width: 300
								anchors { left: parent.left; top: parent.top; bottom: parent.bottom }

								resizePolicy { top: true; right: true; minimumWidth: 230; maximumWidth: 800; minimumHeight: 300; maximumHeight: mainPerspectiveContainer.height; }
								maximizeButtonVisible: false
								popoutButtonVisible: false

								property variant recentQueries: []
								property variant recentQueriesPtr: recentQueries ? recentQueries.map(function(query) { return query.toSharedPointer(); }) : null
								function addToRecentQueries(query) {
									var newQueryPtr = query.clone();

									// Update list
									var list = recentQueries;
									list.unshift(TypeHelper.unboxSharedPointer(newQueryPtr));
									if (list.length > 5)
										list.pop();
									recentQueries = list;
								}

								PerspectiveUi.PerspectiveDeviceList {
									id: deviceListPanel
									anchors { fill: parent; leftMargin: -1 }
									visible: searchPanelStateGroup.state === "device_list"
									context: currentPerspective && currentPerspective.context || null
								}

								SearchComboBox {
									id: searchComboBox

									anchors { left: parent.left; leftMargin: -1; right: parent.right }
									parentWindow: globalSearchContainer.detached ? globalSearchContainer.detachedWindow : globalApplicationWindow

									height: 20
									prefix: qsTr("Searching for : ")
									color: "white"
									fontSize: 13

									queryModel: globalSearchContainer.recentQueries.map(function(query) { return query.name; })

									packagePanelsNames: (searchPanelsContainer.localPanelsInfo || []).map(function(panelInfo) { return panelInfo.panelName; })

									reportsAvailable: globalPermissionsManager.reportsReadPermission.allowed && !!currentPerspective && !!currentPerspective.context && !!currentPerspective.context.alarmQueryService
									onReportsAvailableChanged: if (!reportsAvailable && reportSearchPanel.visible) searchPanelStateGroup.state = "disabled"
									alarmsAvailable: globalPermissionsManager.eventAlarmSearchReadPermission.allowed && !!currentPerspective && !!currentPerspective.context && !!currentPerspective.context.alarmQueryService
									onAlarmsAvailableChanged: if (!alarmsAvailable && alarmSearchPanel.visible) searchPanelStateGroup.state = "disabled"
									eventsAvailable: globalPermissionsManager.eventAlarmSearchReadPermission.allowed && !!currentPerspective && !!currentPerspective.context && !!currentPerspective.context.eventQueryDispatcherService
									onEventsAvailableChanged: if (!eventsAvailable && eventSearchPanel.visible) searchPanelStateGroup.state = "disabled"
									scheduledActivitiesAvailable: globalPermissionsManager.scheduledActivityPermission.allowed && !!currentPerspective && !!currentPerspective.context && !!currentPerspective.context.alarmQueryService
									onScheduledActivitiesAvailableChanged: if (!scheduledActivitiesAvailable && scheduledActivitySearchPanel.visible) searchPanelStateGroup.state = "disabled"

									onSearchClicked: searchPanelStateGroup.state = panel

									onQueryClicked: {
										if (queryIndex < 0 || queryIndex > globalSearchContainer.recentQueries.length)
											return;

										var queryPtr = globalSearchContainer.recentQueries[queryIndex].clone();
										var query = TypeHelper.unboxSharedPointer(queryPtr);
										if (MetaObject.inherits(query, "GUI::USEcurity::events::StoredEventQuery")) {
											selectedPanel = "events";
											eventQueryPanelController.setQuery(query);
											eventQueryPanelController.startQuery();
										} else if (MetaObject.inherits(query, "GUI::USEcurity::alarms::StoredAlarmQuery")) {
											selectedPanel = "alarms";
											alarmQueryPanelController.setQuery(query);
											alarmQueryPanelController.startQuery();
										} else if (MetaObject.inherits(query, "GUI::USEcurity::resources::StoredResourceQuery")) {
											selectedPanel = "resources";
											resourceQueryPanelController.setQuery(query);
											resourceQueryPanelController.startQuery();
										}
									}
								}
								// SearchComboBox

								Item {
									id: searchPanelsContainer
									anchors { top: searchComboBox.bottom; left: parent.left; bottom: parent.bottom; right: parent.right }

									property variant localPanelsInfo: []
									property variant remotePanelsInfo: []

									//This timer is needed because we need to make sure every package component as been created before copying the scope
									Timer {
										id: packagesDelayTimer
										interval: 100
										running: packagesManager.ready
										onTriggered: {
											remoteQueryPanelsScope.transferRemoteScopes();
											searchPanelsContainer.localPanelsInfo = packagesManager && packagesManager.ready && packagesManager.getContent("queryPanel", searchPanelsContainer) || []
											searchPanelsContainer.remotePanelsInfo = packagesManager && packagesManager.ready && packagesManager.getContent("queryPanel", remoteQueryPanelsScope) || []
										}
									}

									property Item activePanel: alarmSearchPanel
									StateGroup {
										id: searchPanelStateGroup
										state: "disabled"
										onStateChanged: {
											globalSearchContainer.visible = (state !== "disabled")
											if (globalSearchContainer.visible) {
												if (state === "device_list") globalSearchContainer.width = 275;
												else globalSearchContainer.width = 400;
											}
											}
										 states: [
											State {
												name: "disabled";
											},
											State {
												name: "freetext";
												PropertyChanges { target: searchPanelsContainer; activePanel: freeTextSearchPanel }
												PropertyChanges { target: globalSearchContainer; title: qsTr("Finder") }
												PropertyChanges { target: searchComboBox; selectedPanel: "freetext"; restoreEntryValues: false }
											},
											State {
												name: "alarms";
												PropertyChanges { target: searchPanelsContainer; activePanel: !!currentPerspective && currentPerspective.context && currentPerspective.context.readOnly ? rmsAlarmSearchPanel : alarmSearchPanel }
												PropertyChanges { target: globalSearchContainer; title: qsTr("Search Alarms") }
												PropertyChanges { target: searchComboBox; selectedPanel: "alarms"; restoreEntryValues: false }
											},
											State {
												name: "events";
												PropertyChanges { target: searchPanelsContainer; activePanel: !!currentPerspective && currentPerspective.context && currentPerspective.context.readOnly ? rmsEventSearchPanel : eventSearchPanel }
												PropertyChanges { target: globalSearchContainer; title: qsTr("Search Events") }
												PropertyChanges { target: searchComboBox; selectedPanel: "events"; restoreEntryValues: false }
											},
											State {
												name: "scheduled_activities"
												PropertyChanges { target: searchPanelsContainer; activePanel: !!currentPerspective && currentPerspective.context && currentPerspective.context.readOnly ? rmsScheduledActivitySearchPanel : scheduledActivitySearchPanel }
												PropertyChanges { target: globalSearchContainer; title: qsTr("Search Scheduled Activities") }
												PropertyChanges { target: searchComboBox; selectedPanel: "scheduled_activities"; restoreEntryValues: false }
											},
											State {
												name: "report"
												PropertyChanges { target: searchPanelsContainer; activePanel: !!currentPerspective && currentPerspective.context && currentPerspective.context.readOnly ? rmsReportSearchPanel : reportSearchPanel }
												PropertyChanges { target: globalSearchContainer; title: qsTr("Search Reports") }
												PropertyChanges { target: searchComboBox; selectedPanel: "report"; restoreEntryValues: false }
											},
											State {
												name: "device_list"
												PropertyChanges { target: searchPanelsContainer; activePanel: deviceListPanel }
												PropertyChanges { target: globalSearchContainer; title: qsTr("Device List") }
												PropertyChanges { target: searchComboBox; visible: false }
											}
										]
									}

									TextEdit { id: clipboardText; visible: false }
									OmniQml.ToolTipArea { id: queryExportTooltip; text: qsTr("Query exported to clipboard."); enabled: false; anchors.fill: null; }
									Component { id: storedalarmQueryComponent; Alarms.StoredAlarmQuery { } }
									Component { id: storedEventQueryComponent; Events.StoredEventQuery { } }
									Component { id: storedResourceQueryComponent; Resources.StoredResourceQuery { } }

									function exportToClipboard() {
										var serializedQuery

										if (searchPanelStateGroup.state === "events")
											serializedQuery = TypeHelper.stringBase64FromByteArray(activePanel.generateStoredQuery().serialize());
										else
											serializedQuery = TypeHelper.stringBase64FromByteArray(activePanel.controller.serializedQuery());

										if (!serializedQuery) return;

										clipboardText.text = "\"" + serializedQuery + "\"";
										clipboardText.selectAll();
										clipboardText.copy();
									}

									function importFromClipboard() {
										clipboardText.text = "";
										clipboardText.paste();
										clipboardText.text.replace("\"", "");
										var value = clipboardText.text

										// Event Query
										var storedQuery = storedEventQueryComponent.createObject(null);
										storedQuery.deserialize(TypeHelper.stringBase64ToByteArray(value));
										if(storedQuery.eventQueryInfoData) {
											activePanel.setFromStoredQuery(storedQuery);
											searchPanelStateGroup.state = "events"
											return;
										}

										// Alarm Query
										storedQuery = storedalarmQueryComponent.createObject(null);
										storedQuery.deserialize(TypeHelper.stringBase64ToByteArray(value));
										if(storedQuery.alarmQueryInfoData) {
											activePanel.setFromStoredQuery(storedQuery);
											searchPanelStateGroup.state = "alarms"
											return;
										}

										// Resource Query
										storedQuery = storedResourceQueryComponent.createObject(null);
										storedQuery.deserialize(TypeHelper.stringBase64ToByteArray(value));
										if(storedQuery.resourceQueryInfoData) {
											activePanel.setFromStoredQuery(storedQuery);
											searchPanelStateGroup.state = "resources"
											return;
										}

										Utilities.information(qsTr("Failed to import query"), qsTr("Unrecognized query structure."));
									}

									Item {
										id: freeTextSearchPanel

										anchors.fill: parent
										visible: searchPanelStateGroup.state === "freetext"
										onVisibleChanged: if (visible) giveFocus()

										function giveFocus() { searchTextInput.giveFocus() }
										Keys.onEscapePressed: searchPanelStateGroup.state = "disabled"

										property QtObject previousController: null
										property QtObject mapControllerCombiner: visible && currentPerspective && currentPerspective.context && currentPerspective.context.mapController && currentPerspective.context.mapController.objectCombiner || null
										onMapControllerCombinerChanged: {
											if (previousController) previousController.modelsContainer.remove(resultsCombiner);
											if (mapControllerCombiner) mapControllerCombiner.modelsContainer.append(resultsCombiner);
											previousController = mapControllerCombiner;
										}
										ObjectListModelCombiner { id: resultsCombiner }

										ScopeResolveAll {
											id: queryViewsResolver
											key: "queryView"
											resolutionMode: ScopeResolveAll.FullTreeMode

											property variant scopeQueries: []
											onValuesChanged: {
												var sortedQueryViews = values.map(function(queryView) { return { index: MetaObject.indexKeyRelativeToObject(queryView, main), queryView: queryView }; });
												sortedQueryViews.sort(compareIndexedSink);
												scopeQueries = sortedQueryViews.map(function(ex) { return ex.queryView; });
											}
											function compareIndexedSink(a, b) {
												var aParts = a.index.split(".");
												var bParts = b.index.split(".");
												for (var i = 0; i < aParts.length; ++i) {
													if (i >= bParts.length) return 1;
													if (aParts[i] === bParts[i]) continue;
													return aParts[i]-bParts[i];
												}
												return aParts.length === bParts.length ? 0 : -1;
											}
									}

										Item {
										id: worldObjectQuery

										property string type: "worldObject"
										property string title: qsTr("World Objects")
										property QtObject completeModel: ObjectListModelCombiner {
											ObjectContainerModel { objectContainer: world && world.placemarksContainer || null }
											ObjectContainerModel { objectContainer: ObjectContainer { objectList: [].concat.apply([], (world && world.maps2DContainer.objectList || []).map(function(map) { return map.markers.objectList; })).map(function(marker) { return marker.placemark; }); } }
											ObjectContainerModel { objectContainer: world && world.floorsContainer || null }
											ObjectContainerModel { objectContainer: world && world.maps2DContainer || null }
										}

										property list<QtObject> columns: [
												StyledTableViewColumn {
													title: qsTr("Object Name")
													name: "objectName"
													role: "modelData"
													width: 200
													delegate: StyledTableViewIconTextCell {
														text: styleData.value ? styleData.value.name : ""
														source: "qrc" + MetaObject.classInfoValue(styleData.value, "mimeIcon");
													}
													sortCriteria: ObjectStringPropertyComparator { property: "name" }
												},

												StyledTableViewColumn {
													title: qsTr("Type")
													name: "objectType"
													role: "modelData"
													width: 150
													delegate: StyledTableViewTextCell { text: qsTranslate("WorldObject", MetaObject.classInfoValue(styleData.value, "mimeType")); }
													sortCriteria: OmniWorld.WorldTypeComparator { }
												},

												StyledTableViewColumn {
													title: qsTr("Location")
													name: "objectLocation"
													role: "modelData"
													width: 200
													delegate: StyledTableViewTextCell { text: world.locationFor(styleData.value || null) || qsTr("No floor location found"); }
													sortCriteria: OmniWorld.WorldLocationComparator { world: main.world }
												}
											]
									}

										Item {
											id: packageQueriesLoader

											property variant packageQueries: []
											Connections {
												target: packagesManager
												onReadyChanged: {
													var queryProviders = packagesManager.ready && packagesManager.getContent("freeTextQueryProvider", queryViewsResolver) || null;
													var queries = [].concat.apply([], queryProviders);
													queries.forEach(function(query) { MetaObject.cast(query).filterText = function() { return searchTextInput.filterText; }; });
													packageQueriesLoader.packageQueries = queries;
												}
											}
									}

										StyledFlickable {
										id: filteredResultsColumnFlickable
										anchors { fill: parent; topMargin: 1 }
										contentHeight: filteredResultsColumn.height + 20
										clip: true

										Column {
											id: filteredResultsColumn
											y: 10
											anchors { left: parent.left; right: parent.right; margins: 10 }
											spacing: 5

											StyledTextInput {
													id: searchTextInput

													height: visible ? 24 : 0
													anchors { left: parent.left; right: parent.right }
													clearButtonVisible: true
													emptyText: qsTr("Search")

													onEnterPressed: updateFilterText()
													onEscapePressed: freeTextSearchPanel.forceActiveFocus()
													onTextChanged: { minTimeout.restart(); maxTimeout.start(); }

													Timer { id: minTimeout; interval: 1000; onTriggered: searchTextInput.updateFilterText(); }
													Timer { id: maxTimeout; interval: 3000; onTriggered: searchTextInput.updateFilterText(); }

													function updateFilterText() {
														searchTextInput.filterText = searchTextInput.text;
														minTimeout.stop();
														maxTimeout.stop();
													}

													property alias filterText: tokenMatcher.text

													TextExtractionFilter {
														id: textFilter

														textExtractionTarget: TokenMatchingTextExtractionTarget { id: tokenMatcher }
														textExtractor: TextExtractorComposite {
														TextExtractorComposite {
																id: eventAndRelatedSiteTextExtractor

																Events.EventTextExtractor {
																	sourceRegistryCache: _private.localServices.caches.eventSourceRegistryCache
																	eventDisplayNameResolver: globalEventTypeHierarchy.displayNameResolver
																}
																Federation.SiteTextExtractor {
																	// Supports extracting site names from Event Objects
																	siteRegistryCache: globalSiteRegistryCache
																}
															}

														Alarms.AlarmTextExtractor {
																// Need to aggregate all the event caches...
																eventCache: currentPerspective && currentPerspective.context && currentPerspective.context.eventCache
																eventTextExtractor: eventAndRelatedSiteTextExtractor
																sopDataStoreCache: _private.localServices.caches.sopDatastoreCache
																userRegistryCache: globalUserRegistryCache
																userRegistryGroupCache: globalGroupRegistryCache
															}

														Resources.ResourceTextExtractor {
																siteRegistryCache: globalSiteRegistryCache
															}

														OmniWorld.WorldObjectTextExtractor {}
													}
												}
											}

											StyledText {
													anchors { left: parent.left; right: parent.right }
													visible: searchTextInput.text === "" && searchTextInput.filterText === ""
													text: qsTr("Enter text to begin searching.")
													horizontalAlignment: Text.AlignHCenter
												}

											Repeater {
													id: filteredResultViewRepeater
													model: StableObjectListModel {
														id: queryViewsModel
														objectList: packageQueriesLoader.packageQueries.concat(worldObjectQuery).concat(queryViewsResolver.scopeQueries)
													}

													Item {
														id: filteredResultsDelegate
														anchors { left: parent ? parent.left : undefined; right: parent ? parent.right : undefined }

														visible: filteredModel.ItemModelExtender.count > 0
														height: visible ? tableContainer.y + tableContainer.height + 5 : 0

														property QtObject queryView: modelData
														property alias filteredModel: filteredModel

														StyledTextHeader {
															id: headerText
															anchors { left: parent.left; leftMargin: 5; right: parent.right }
															elide: Text.ElideRight

															text: filteredModel.ItemModelExtender.count + " " + filteredResultsDelegate.queryView.title
														}

														StyledBorderRectangle {
															id: tableContainer
															anchors { left: parent.left; right: parent.right; top: headerText.bottom; topMargin: 5 }
															height: table.headerHeight + table.scrollbarSize + Math.min(table.model.ItemModelExtender.count, 5) * table.rowHeight

															StyledTableView {
																id: table
																anchors { fill: parent; leftMargin: 1 }
																sortIndicatorVisible: true
																columns: {
																	var newColumns = [];
																	for (var i = 0; i < expectedColumns.length; ++i) {
																		newColumns.push(expectedColumns[i]);
																	}
																	return newColumns;
																}
																selection: Selection.SelectionControllerTableViewSelection {
																	model: filteredModel
																}
																onDoubleClicked: globalSelectionController.activateSelection()
																onRightClicked: globalSelectionController.showContextMenu()

																property variant expectedColumns: filteredResultsDelegate.queryView && filteredResultsDelegate.queryView.columns || []

																model: ObjectSortFilterProxyModel {
																	id: filteredModel
																	sourceModel: searchTextInput.filterText != "" && filteredResultsDelegate.queryView && filteredResultsDelegate.queryView.completeModel || null
																	filter: textFilter
																	sortComparator: ObjectComparatorInverter {
																		comparator: table.columns[table.sortIndicatorColumn] && table.columns[table.sortIndicatorColumn].sortCriteria || null
																		inverted: table.sortIndicatorOrder === Qt.DescendingOrder
																	}
																	Component.onCompleted: resultsCombiner.modelsContainer.append(filteredModel)
																}
															}
														}
													}
												}
										}
									}
									}


									// Display the Alarm Query tool
									//--------------------------------------
									Queries.QueryPanel {
										id: alarmSearchPanel
										anchors.fill: parent
										visible: searchPanelStateGroup.state === "alarms" && !!currentPerspective.context && !currentPerspective.context.readOnly
										timeline: globalTimeline

										name: "alarmQueryPanel"

										property variant notificationConfigurationShared: controller.notificationConfiguration ? controller.notificationConfiguration.toSharedPointer() : null

										context: Queries.ConditionEditorContext {
											templateDatabase: Queries.AlarmConditionEditorTemplateDatabase { property QtObject context: alarmSearchPanel.context }
											dataStores: QtObject {
												property QtObject procedureTagDataStore: Sops.ProcedureTagDataStore {}
											}
											caches: QtObject {
												property QtObject sopCache: _private.localServices.caches.sopDatastoreCache
												property QtObject alarmPriorityCache: globalAlarmPriorityDataStoreCache
												property QtObject eventSourceRegistryCache: _private.localServices.caches.eventSourceRegistryCache
												property QtObject siteRegistryCache: globalSiteRegistryCache
												property QtObject userCache: globalUserRegistryCache
												property QtObject groupCache: globalGroupRegistryCache
												property QtObject procedureOverrideCache: _private.localServices.caches.procedureOverrideCache
											}
											eventTypeHierarchy: globalEventTypeHierarchy
											world: main.world
										}
										controller: Queries.AlarmQueryPanelController {
											id: alarmQueryPanelController
											context: alarmSearchPanel.context
											queryService: _private.localServices.alarmQueryService
											queryDataStore: _private.localServices.alarmQueryDatastore
											queryDataStoreCache: _private.localServices.caches.alarmQueryCache

											eventCache: _private.localServices.caches.eventCache
											eventQueryService: _private.localServices.eventQueryDispatcherService
											eventSourceRegistryCache: _private.localServices.caches.eventSourceRegistryCache
											eventSourceResolver: _private.localServices.eventSourceResolver
											eventDisplayNameResolver: globalEventTypeHierarchy.displayNameResolver
											alarmPriorityCache: globalAlarmPriorityDataStoreCache
											userCache: globalUserRegistryCache
											sopCache: _private.localServices.caches.sopDatastoreCache
											timeline: globalTimeline
											tableViewConfiguration: alarmSearchPanel.tableViewConfiguration
											currentSiteId: globalSiteRegistryCache.currentSiteData && globalSiteRegistryCache.currentSiteData._id
											packagesManager: packagesManager

											maximumResultCount: globalActiveConfiguration && globalActiveConfiguration.maximumSearchResultCount || 1000
											canOpenQueries: globalPermissionsManager.alarmQueryOpenPermission.allowed && !queryDataStoreCache.updating
											canSaveQueries: globalPermissionsManager.alarmQuerySavePermission.allowed && !queryDataStoreCache.updating
											onLoadingQuery: searchPanelStateGroup.state = "alarms"
										}

										resultTableSelection: Selection.SelectionControllerTableViewSelection {
											model: alarmSearchPanel.searchResultModel
										}

										onResultDoubleClicked: globalSelectionController.activateSelection()
										onResultRightClicked: globalSelectionController.showContextMenu()
										onResultMiddleClicked: {
											if (!currentPerspective.context || !globalActiveConfiguration || !globalActiveConfiguration.closeAlarmsOnMiddleClick || currentPerspective.context.readOnly || !globalSelectionController.selection) return;

											var selections = globalSelectionController.selection.selections ? globalSelectionController.selection.selections.objectList : [globalSelectionController.selection];
											var alarms = selections.map(function (selection) { return selection.alarm || null; }).filter(function (selection) { return !!selection; });
											globalLocalOperations.closeCloseableAlarms(alarms);
										}
										// FIXME: Close all alarms from all dashboards
										// onResultMiddleClickHeld:
									}
									// AlarmSearchPanel--------------------------------------

									// Display the Event Query tool
									// -------------------------------------
									Queries.QueryPanel {
										id: eventSearchPanel

										anchors.fill: parent
										visible: searchPanelStateGroup.state === "events" && !!currentPerspective.context && !currentPerspective.context.readOnly
										timeline: globalTimeline

										context: Queries.ConditionEditorContext {
											templateDatabase: Queries.EventConditionEditorTemplateDatabase { property QtObject context: eventSearchPanel.context }
											caches: QtObject {
												property QtObject siteRegistryCache: globalSiteRegistryCache
												property QtObject eventSourceRegistryCache: _private.localServices.caches.eventSourceRegistryCache
												property QtObject objectTagCache: _private.localServices.caches.objectTagCache
											}
											services: QtObject {
												property QtObject genericObjectDataStore: _private.localServices.genericObjectDatastore && _private.localServices.genericObjectDatastore.serviceReferenceData ? _private.localServices.genericObjectDatastore : null
												property QtObject permissionsProvider: _private.localServices.permissionsProvider &&_private.localServices.permissionsProvider.serviceReferenceData ? _private.localServices.permissionsProvider : null
											}
											dataStores: QtObject {
												property QtObject genericObjectDatastore: _private.localServices.genericObjectDatastore
											}
											world: main.world
											property QtObject mapResolver: _private.localServices.mapResolver

											property QtObject packagesManager: packagesManager
											eventTypeHierarchy: globalEventTypeHierarchy
										}
										controller: Queries.EventQueryPanelController {
											id: eventQueryPanelController
											context: eventSearchPanel.context
											queryService: _private.localServices.eventQueryDispatcherService
											queryDataStore: _private.localServices.eventQueryDatastore
											queryDataStoreCache: _private.localServices.caches.eventQueryCache

											timeline: globalTimeline
											eventTypeHierarchy: globalEventTypeHierarchy
											eventSourceRegistryCache: _private.localServices.caches.eventSourceRegistryCache
											eventSourceResolver: _private.localServices.eventSourceResolver
											currentSiteId: globalSiteRegistryCache.currentSiteData && globalSiteRegistryCache.currentSiteData._id
											packagesManager: packagesManager

											maximumResultCount: globalActiveConfiguration && globalActiveConfiguration.maximumSearchResultCount || 1000
											canOpenQueries: globalPermissionsManager.eventQueryOpenPermission.allowed && !queryDataStoreCache.updating
											canSaveQueries: globalPermissionsManager.eventQuerySavePermission.allowed && !queryDataStoreCache.updating
											onLoadingQuery: searchPanelStateGroup.state = "events"
											onSearchStarted: searchPanelStateGroup.state = "events"
										}

										resultTableSelection: Selection.SelectionControllerTableViewSelection {
											model: eventSearchPanel.searchResultModel
										}

										onResultDoubleClicked: globalSelectionController.activateSelection()
										onResultRightClicked: globalSelectionController.showContextMenu()
									}
									// EventSearchPanel --------------------------------------


									// Display the Scheduled Activity Search Panel
									//---------------------------------------------
									Queries.QueryPanel {
										id: scheduledActivitySearchPanel
										anchors.fill: parent
										visible: searchPanelStateGroup.state === "scheduled_activities" && !!currentPerspective.context && !currentPerspective.context.readOnly

										context: Queries.ConditionEditorContext {
											templateDatabase: Queries.ScheduledActivityConditionEditorTemplateDatabase { property QtObject context: scheduledActivitySearchPanel.context }
											caches: QtObject {
												property QtObject procedureRecordCache: _private.localServices.caches.procedureRecordCache
											}
											dataStores: QtObject {
												property QtObject procedureRecordDataStore: _private.localServices.procedureRecordDatastore
											}
											eventTypeHierarchy: globalEventTypeHierarchy
											world: main.world
										}

										controller: Queries.ScheduledActivityQueryPanelController {
											context: scheduledActivitySearchPanel.context
											queryService: _private.localServices.alarmQueryService
											tableViewConfiguration: scheduledActivitySearchPanel.tableViewConfiguration
											eventCache: _private.localServices.caches.eventCache
											eventQueryService: _private.localServices.eventQueryDispatcherService

											maximumResultCount: globalActiveConfiguration && globalActiveConfiguration.maximumSearchResultCount || 1000
											onLoadingQuery: searchPanelStateGroup.state = "scheduled_activities"
										}

										resultTableSelection: Selection.SelectionControllerTableViewSelection {
											model: scheduledActivitySearchPanel.searchResultModel
										}

										onResultDoubleClicked: globalSelectionController.activateSelection()
										onResultRightClicked: globalSelectionController.showContextMenu()
									}
									// ScheduledActivitySearchPanel ------------------------------

									// Display the Report search Panel
									//--------------------------------------------------
									Queries.QueryPanel {
										id: reportSearchPanel
										anchors.fill: parent
										visible: searchPanelStateGroup.state === "reports" && !!currentPerspective.context && !currentPerspective.context.readOnly

										context: Queries.ConditionEditorContext {
											templateDatabase: Queries.ReportConditionEditorTemplateDatabase { property QtObject context: reportSearchPanel.context }
											caches: QtObject {
												property QtObject sopCache: _private.localServices.caches.sopDatastoreCache
												property QtObject siteRegistryCache: globalSiteRegistryCache
											}
											eventTypeHierarchy: globalEventTypeHierarchy
											world: main.world
										}

										controller: Queries.ReportQueryPanelController {
											context: reportSearchPanel.context
											queryService: _private.localServices.alarmQueryService
											tableViewConfiguration: reportSearchPanel.tableViewConfiguration

											eventCache: _private.localServices.caches.eventCache
											eventQueryService: _private.localServices.eventQueryDispatcherService
											eventDisplayNameResolver: globalEventTypeHierarchy.displayNameResolver
											sopCache: _private.localServices.caches.sopDatastoreCache
											timeline: globalTimeline

											maximumResultCount: globalActiveConfiguration && globalActiveConfiguration.maximumSearchResultCount || 1000
											onLoadingQuery: searchPanelStateGroup.state = "reports"
										}

										resultTableSelection: Selection.SelectionControllerTableViewSelection {
											model: reportSearchPanel.searchResultModel
										}

										onResultDoubleClicked: globalSelectionController.activateSelection()
										onResultRightClicked: globalSelectionController.showContextMenu()
									}
									// ReportSearchPanel -------------------------------

									Repeater {
										id: packagesPanelRepeater
										model: searchPanelsContainer.localPanelsInfo

										property variant panels: []

										Queries.QueryPanel {
											id: queryPanel
											anchors.fill: parent
											visible: searchPanelStateGroup.state === panelInfo.panelName && !!currentPerspective.context && !currentPerspective.context.readOnly

											property QtObject panelInfo: modelData

											context: panelInfo.context
											controller: panelInfo.controller
											resultTableSelection: panelInfo.resultTableSelection

											onResultDoubleClicked: globalSelectionController.activateSelection()
											onResultRightClicked: globalSelectionController.showContextMenu()

											Connections {
												target: queryPanel.controller
												onLoadingQuery: searchPanelStateGroup.state = queryPanel.panelInfo.panelName
											}

											Binding {
												target: queryPanel.panelInfo
												property: "searchResultModel"
												value: queryPanel.searchResultModel
											}

											Binding {
												target: queryPanel.panelInfo
												property: "tableViewConfiguration"
												value: queryPanel.tableViewConfiguration
											}

											ScopePublish {
												key: modelData.panelDependencyType
												value: queryPanel
											}

											Component.onCompleted: {
												var panels = packagesPanelRepeater.panels;
												panels.push(queryPanel);
												packagesPanelRepeater.panels = panels;
											}

											Component.onDestruction: {
												var panels = packagesPanelRepeater.panels;
												var index = panels.indexOf(queryPanel);

												if (index !== -1) {
													panels.splice(index, 1);
													packagesPanelRepeater.panels = panels;
												}
											}
										}
									}

									// RMS Search Panels
									ResolutionScope {
										id: remoteQueryPanelsScope

										anchors.fill: parent

										name: "remoteAlarmQueryPanelRMSScope"

										function transferRemoteScopes() {
											var scopes = _private.remoteServices.getPublishers();
											for (var i = 0; i < scopes.length; ++i)
												var newScope = scopePublishComponent.createObject(remoteQueryPanelsScope, { key: scopes[i].key, sourceScope: scopes[i] });
										}

										Queries.QueryPanel {
											id: rmsAlarmSearchPanel
											anchors.fill: parent
											visible: searchPanelStateGroup.state === "alarms" && !!currentPerspective.context && currentPerspective.context.readOnly
											timeline: globalTimeline

											name: "remoteAlarmQueryPanel"

											property variant notificationConfigurationShared: controller.notificationConfiguration ? controller.notificationConfiguration.toSharedPointer() : null

											context: Queries.ConditionEditorContext {
												templateDatabase: Queries.AlarmConditionEditorTemplateDatabase { property QtObject context: rmsAlarmSearchPanel.context }
												dataStores: QtObject {
													property QtObject procedureTagDataStore: Sops.ProcedureTagDataStore {}
												}
												caches: QtObject {
													property QtObject sopCache: _private.remoteServices.caches.sopDatastoreCache
													property QtObject alarmPriorityCache: globalAlarmPriorityDataStoreCache
													property QtObject eventSourceRegistryCache: _private.remoteServices.caches.eventSourceRegistryCache
													property QtObject siteRegistryCache: globalSiteRegistryCache
													property QtObject userCache: globalUserRegistryCache
													property QtObject groupCache: globalGroupRegistryCache
													property QtObject procedureOverrideCache: _private.remoteServices.caches.procedureOverrideCache
												}
												eventTypeHierarchy: globalEventTypeHierarchy
												world: main.world
											}
											controller: Queries.AlarmQueryPanelController {
												context: rmsAlarmSearchPanel.context
												queryService: _private.remoteServices.alarmQueryService
												queryDataStore: _private.localServices.alarmQueryDatastore
												queryDataStoreCache: _private.localServices.caches.alarmQueryCache

												eventCache: _private.remoteServices.caches.eventCache
												eventQueryService: _private.remoteServices.eventQueryDispatcherService
												eventSourceRegistryCache: _private.remoteServices.caches.eventSourceRegistryCache
												eventSourceResolver: _private.remoteServices.eventSourceResolver
												eventDisplayNameResolver: globalEventTypeHierarchy.displayNameResolver
												alarmPriorityCache: globalAlarmPriorityDataStoreCache
												userCache: globalUserRegistryCache
												sopCache: _private.remoteServices.caches.sopDatastoreCache
												timeline: globalTimeline
												tableViewConfiguration: rmsAlarmSearchPanel.tableViewConfiguration
												currentSiteId: globalSiteRegistryCache.currentSiteData && globalSiteRegistryCache.currentSiteData._id
												packagesManager: packagesManager

												maximumResultCount: globalActiveConfiguration && globalActiveConfiguration.maximumSearchResultCount || 1000
												onLoadingQuery: searchPanelStateGroup.state = "alarms"
											}

											resultTableSelection: Selection.SelectionControllerTableViewSelection {
												model: rmsAlarmSearchPanel.searchResultModel
											}

											onResultDoubleClicked: globalSelectionController.activateSelection()
											onResultRightClicked: globalSelectionController.showContextMenu()
										}

										Queries.QueryPanel {
											id: rmsEventSearchPanel
											anchors.fill: parent
											visible: searchPanelStateGroup.state === "events" && !!currentPerspective.context && currentPerspective.context.readOnly
											timeline: globalTimeline

											context: Queries.ConditionEditorContext {
												templateDatabase: Queries.EventConditionEditorTemplateDatabase { property QtObject context: rmsEventSearchPanel.context }
												caches: QtObject {
													property QtObject siteRegistryCache: globalSiteRegistryCache
													property QtObject eventSourceRegistryCache: _private.remoteServices.caches.eventSourceRegistryCache
													property QtObject objectTagCache: _private.remoteServices.caches.objectTagCache
												}
												services: QtObject {
													property QtObject genericObjectDataStore: _private.remoteServices.genericObjectDatastore && _private.remoteServices.genericObjectDatastore.serviceReferenceData ? _private.remoteServices.genericObjectDatastore : null
													property QtObject permissionsProvider: _private.localServices.permissionsProvider && _private.localServices.permissionsProvider.serviceReferenceData ? _private.localServices.permissionsProvider : null
												}
												dataStores: QtObject {
													property QtObject genericObjectDatastore: _private.remoteServices.genericObjectDatastore
												}
												world: main.world
												property QtObject mapResolver: _private.remoteServices.mapResolver
												property QtObject packagesManager: packagesManager
												eventTypeHierarchy: globalEventTypeHierarchy
											}
											controller: Queries.EventQueryPanelController {
												context: rmsEventSearchPanel.context
												queryService: _private.remoteServices.eventQueryDispatcherService
												queryDataStore: _private.localServices.eventQueryDatastore
												queryDataStoreCache: _private.localServices.caches.eventQueryCache

												timeline: globalTimeline
												eventTypeHierarchy: globalEventTypeHierarchy
												eventSourceRegistryCache: _private.remoteServices.caches.eventSourceRegistryCache
												eventSourceResolver: _private.remoteServices.eventSourceResolver
												currentSiteId: globalSiteRegistryCache.currentSiteData && globalSiteRegistryCache.currentSiteData._id
												packagesManager: packagesManager

												maximumResultCount: globalActiveConfiguration && globalActiveConfiguration.maximumSearchResultCount || 1000
												canOpenQueries: globalPermissionsManager.eventQueryOpenPermission.allowed && !queryDataStoreCache.updating
												canSaveQueries: globalPermissionsManager.eventQueryOpenPermission.allowed && !queryDataStoreCache.updating
												onLoadingQuery: searchPanelStateGroup.state = "events"
												onSearchStarted: searchPanelStateGroup.state = "events"
											}

											resultTableSelection: Selection.SelectionControllerTableViewSelection {
												model: rmsEventSearchPanel.searchResultModel
											}

											onResultDoubleClicked: globalSelectionController.activateSelection()
											onResultRightClicked: globalSelectionController.showContextMenu()
										}

										Queries.QueryPanel {
											id: rmsScheduledActivitySearchPanel
											anchors.fill: parent
											visible: searchPanelStateGroup.state === "scheduled_activities" && !!currentPerspective.context && currentPerspective.context.readOnly

											context: Queries.ConditionEditorContext {
												templateDatabase: Queries.ScheduledActivityConditionEditorTemplateDatabase { property QtObject context: rmsScheduledActivitySearchPanel.context }
												caches: QtObject {
													property QtObject procedureRecordCache: _private.remoteServices.caches.procedureRecordCache
												}
												dataStores: QtObject {
													property QtObject procedureRecordDataStore: _private.remoteServices.procedureRecordDatastore
												}
												eventTypeHierarchy: globalEventTypeHierarchy
												world: main.world
											}

											controller: Queries.ScheduledActivityQueryPanelController {
												context: rmsScheduledActivitySearchPanel.context
												queryService: _private.remoteServices.alarmQueryService
												tableViewConfiguration: rmsScheduledActivitySearchPanel.tableViewConfiguration

												maximumResultCount: globalActiveConfiguration && globalActiveConfiguration.maximumSearchResultCount || 1000
												onLoadingQuery: searchPanelStateGroup.state = "scheduled_activities"
											}

											resultTableSelection: Selection.SelectionControllerTableViewSelection {
												model: rmsScheduledActivitySearchPanel.searchResultModel
											}

											onResultDoubleClicked: globalSelectionController.activateSelection()
											onResultRightClicked: globalSelectionController.showContextMenu()
										}

										Queries.QueryPanel {
											id: rmsReportSearchPanel

											anchors.fill: parent
											visible: searchPanelStateGroup.state === "reports" && !!currentPerspective.context && currentPerspective.context.readOnly

											context: Queries.ConditionEditorContext {
												templateDatabase: Queries.ReportConditionEditorTemplateDatabase { property QtObject context: rmsReportSearchPanel.context }
												caches: QtObject {
													property QtObject sopCache: _private.remoteServices.caches.sopDatastoreCache
													property QtObject siteRegistryCache: globalSiteRegistryCache
												}

												eventTypeHierarchy: globalEventTypeHierarchy
												world: main.world
											}

											controller: Queries.ReportQueryPanelController {
												context: rmsReportSearchPanel.context
												queryService: _private.remoteServices.alarmQueryService
												tableViewConfiguration: rmsReportSearchPanel.tableViewConfiguration

												eventCache: _private.remoteServices.caches.eventCache
												eventQueryService: _private.remoteServices.eventQueryDispatcherService
												eventDisplayNameResolver: globalEventTypeHierarchy.displayNameResolver
												sopCache: _private.remoteServices.caches.sopDatastoreCache
												timeline: globalTimeline

												maximumResultCount: globalActiveConfiguration && globalActiveConfiguration.maximumSearchResultCount || 1000
												onLoadingQuery: searchPanelStateGroup.state = "reports"
											}

											resultTableSelection: Selection.SelectionControllerTableViewSelection {
												model: rmsReportSearchPanel.searchResultModel
											}

											onResultDoubleClicked: globalSelectionController.activateSelection()
											onResultRightClicked: globalSelectionController.showContextMenu()
										}

										Repeater {
											id: remotePackagesPanelRepeater
											model: searchPanelsContainer.remotePanelsInfo

											property variant panels: []

											Queries.QueryPanel {
												id: queryPanel
												anchors.fill: parent
												visible: searchPanelStateGroup.state === panelInfo.panelName && !!currentPerspective.context && currentPerspective.context.readOnly

												property QtObject panelInfo: modelData

												context: panelInfo.context
												controller: panelInfo.controller
												resultTableSelection: panelInfo.resultTableSelection

												onResultDoubleClicked: globalSelectionController.activateSelection()
												onResultRightClicked: globalSelectionController.showContextMenu()

												Connections {
													target: queryPanel.controller
													onLoadingQuery: searchPanelStateGroup.state = queryPanel.panelInfo.panelName
												}

												Binding {
													target: queryPanel.panelInfo
													property: "searchResultModel"
													value: queryPanel.searchResultModel
												}

												Binding {
													target: queryPanel.panelInfo
													property: "tableViewConfiguration"
													value: queryPanel.tableViewConfiguration
												}

												Component.onCompleted: {
													var panels = remotePackagesPanelRepeater.panels;
													panels.push(queryPanel);
													remotePackagesPanelRepeater.panels = panels;
												}

												Component.onDestruction: {
													var panels = remotePackagesPanelRepeater.panels;
													var index = panels.indexOf(queryPanel);

													if (index !== -1) {
														panels.splice(index, 1);
														remotePackagesPanelRepeater.panels = panels;
													}
												}
											}
										}
									}
								}
								// searchPanelsContainer
							}
							// globalSearchContainer
							//-----------------------------------------------------

					}
						// searchZone

						// Layout selector button.
						LayoutSwitcher {
							id: globalLayoutSwitcher

							anchors { top: parent.top; bottom: parent.bottom }
							currentPerspective: main.currentPerspective
							perspectiveLayoutDatabase: globalPerspectiveLayoutDatabase
							visible: layoutTypes.length > 1 && layoutTypes.indexOf(currentPerspective && currentPerspective.context && currentPerspective.context.layout && currentPerspective.context.layout.specification.type || "") !== -1
							layoutTypes: {
								if (currentPerspective && currentPerspective.profile) {
									var layoutTypes = currentPerspective.profile.availableLayoutTypes;
									if (layoutTypes.indexOf(currentPerspective.profile.initialLayoutType) < 0)
										layoutTypes = [currentPerspective.profile.initialLayoutType].concat(layoutTypes);

									return layoutTypes;
								}

								var layouts = globalActiveConfiguration && globalActiveConfiguration.layoutSwitcherLayouts || [];
								var currentInitialLayout = currentPerspective && currentPerspective.initialLayout && currentPerspective.initialLayout.specification.category === "custom_video_layout" && currentPerspective.initialLayout.specification.type || null;
								if (currentInitialLayout && layouts.indexOf(currentInitialLayout) === -1)
									layouts.push(currentInitialLayout);
								return layouts;
								}
						}
						// globalLayoutSwitcher

						StyledBorderRectangle {
							id: layoutButtonContainer
							visible: showLayoutList.checked
							anchors { top: parent.top; bottom: parent.bottom }
							width: globalLayoutContainer.visible ? globalLayoutContainer.width : layoutButton.width

							Item {
									anchors.fill: parent; clip: true // Simple clipping wrapper

									StyledTextButton {
										id: layoutButton
										icon: "ThLarge"; padding: 10
										text: currentPerspective && currentPerspective.context && currentPerspective.context.layout && currentPerspective.context.layout.name || "Perpsective Layout";
										anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
										textColor: "#282725"
										iconColor: "#0080c2"
										width: implicitWidth > 200 ? 200 : implicitWidth
										onClicked: globalLayoutContainer.visible = !globalLayoutContainer.visible
									}
								}


							// Shows the different layouts available in a popup window.
							StyledPopoutContainer {
									id: globalLayoutContainer

									anchors { left: parent.left; bottom: parent.top }
									title: currentPerspective && currentPerspective.context && currentPerspective.context.layout && currentPerspective.context.layout.name || "Perpsective Layout";
									width: 200; height: 200;
									resizePolicy { top: true; right: true; minimumWidth: 100; maximumWidth: 600; minimumHeight: 100; maximumHeight: mainPerspectiveContainer.height * 0.8 }
									visible: false
									onCloseRequested: visible = false

									StyledListView {
										id: layoutListView
										anchors.fill: parent
										highlightFollowsCurrentItem: true;

										model: globalPerspectiveLayoutDatabase.initializedLayouts
										delegate: StyledTextButton {
											height: 20
											property bool selected: currentPerspective && currentPerspective.context &&
																(currentPerspective.context.layout === modelData) || false
											onSelectedChanged: {
												if(selected)
													layoutListView.currentIndex = index;
											}
											text: modelData.name
											onClicked: currentPerspective.context.layout = modelData
										}
									}
								}
					}
						// layoutButtonContainer
					}

					// Display the bottom row of GraphicsUI main window.
					Row {
						id: rightBottomRow
						anchors { top: parent.top; left: leftBottomRow.right; right: parent.right; bottom: parent.bottom }
						layoutDirection: Qt.RightToLeft

						// Shows the "Notifications" button on the botton right side.
						// Allows to show / hide the notification popup.
						StyledBorderRectangle {
						id: notificationZone
						anchors { top: parent.top; bottom: parent.bottom }
						width: 350
						clip: true

						MouseArea {
								id: notificationZoneMouseArea
								anchors.fill: parent
								hoverEnabled: true
								onClicked: {
									if (!window) window = notificationWindowComponent.createObject(notificationZone, { parentWidget: Utilities.applicationWindow() });
									window.nativeWindow.raise();
								}

								property variant window: null

								Component {
									id: notificationWindowComponent

									OmniQml.Window {
										id: notificationWindow
										height: 500
										width: 350
										key: "notificationWindow"
										visible: true
										title: qsTr("Notifications")
										deleteOnClose: true
										property bool showLowPriorityNotifications: false

										StyledText {
											anchors.centerIn: parent
											text: qsTr("No Notifications")
											visible: globalNotificationManager.notificationsModel.ItemModelExtender.count === 0
										}

										ListView {
											id: notificationsFlickable
											anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: notificationsScrollbar.left; margins: 10 }
											spacing: 10
											clip: true
											boundsBehavior: Flickable.StopAtBounds

											model: ObjectSortFilterProxyModel {
												sourceModel: globalNotificationManager.notificationsModel
												sortComparator: ObjectCompositeComparator {
													ObjectUIntPropertyComparator {
														property: "sortPriority"
														order: Qt.DescendingOrder
													}
													ObjectComparatorInverter {
														inverted: true
														comparator: ObjectDateTimeComparator {
															property: "timestamp"
														}
													}
												}
											}

											Component.onDestruction: model = null

											delegate: Loader {
												anchors { left: parent.left; right: parent.right; }
												height: item ? implicitHeight : 0
												property QtObject notificationData: modelData
												sourceComponent: notificationData && notificationData.sortPriority > 0 || notificationWindow.showLowPriorityNotifications ? toastComponent : null
												Component {
													id: toastComponent
													Notifications.NotificationToast {
														anchors { left: parent ? parent.left : undefined; right: parent ? parent.right : undefined; rightMargin: 2 }
														notification: notificationData
														dismissable: false
													}
												}
											}

											section.property: "sortPriority"
											section.criteria: ViewSection.FullString
											section.delegate: Item {
												width: parent.width
												visible: section !== "2" // 2 = HealthMonitoring Notifications
												height: visible ? 30 : 0
												Row {
													id: headerRow
													// Center offset cancels the offset introduced by the section header only having spacing *before*, but not *after*.
													anchors { verticalCenter: parent.verticalCenter; verticalCenterOffset: -5 }
													spacing: 5
													StyledIcon {
														visible: section === "0" // 0 = inactive Notifications
														width: 18
														font.pixelSize: 18
														anchors.verticalCenter: parent.verticalCenter
														color: showSectionArea.containsMouse ? StyledPalette.highlight : "#646263"
														icon: notificationWindow.showLowPriorityNotifications ? "DoubleAngleDown" : "DoubleAngleUp"
													}
													StyledTextHeader {
														anchors.verticalCenter: parent.verticalCenter
														color: showSectionArea.containsMouse ? StyledPalette.highlight : "#646263"
														text: section === "1" ? qsTr("Active Notifications") : qsTr("Past Notifications") // 1 = active Notifications
													}
												}
												MouseArea {
													id: showSectionArea
													hoverEnabled: true
													anchors.fill: headerRow
													onClicked: {
														if(section === "0")
															notificationWindow.showLowPriorityNotifications = !notificationWindow.showLowPriorityNotifications
													}
												}
											}
										}

										StyledFlickableScrollBar {
											id: notificationsScrollbar
											anchors { top: parent.top; bottom: parent.bottom; right: parent.right; rightMargin: visible ? 10 : 0 }
											flickable: notificationsFlickable
											width: visible ? 12 : 0
										}
									}
								}
							}

						StyledText {
								anchors { fill: parent; leftMargin: 10 }
								text: qsTr("Notifications")
								color: notificationZoneMouseArea.containsMouse ? StyledPalette.highlight : "#282725"
							}

						Row {
								anchors { right: parent.right; rightMargin: 10; top: parent.top; bottom: parent.bottom }
								spacing: 10

								Repeater {
									property Item _p: Item {
										ObjectSortFilterProxyModel {
											id: highPriorityNotificationsModel
											sourceModel: globalNotificationManager.notificationsModel
											filter: ObjectIntPropertyFilter {
												property: "priority"
												value: 1
											}
										}
										ObjectSortFilterProxyModel {
											id: normalPriorityNotificationsModel
											sourceModel: globalNotificationManager.notificationsModel
											filter: ObjectIntPropertyFilter {
												property: "priority"
												value: 0
											}
										}
										ObjectSortFilterProxyModel {
											id: inProgressNormalPriorityNotificationsModel
											sourceModel: normalPriorityNotificationsModel
											filter: ObjectBoolPropertyFilter {
												property: "inProgress"
											}
										}
										QtObject {
											id: highPriorityNotifications
											property string icon: "TimesCircle"
											property string color: "#ff7878"
											property int count: highPriorityNotificationsModel.ItemModelExtender.count
											property string label: qsTr("Critical Notifications")
										}
										QtObject {
											id: normalPriorityNotifications
											property string icon: "ExclamationTriangle"
											property string color: "#ffb347"
											property int count: normalPriorityNotificationsModel.ItemModelExtender.count - inProgressNormalPriorityNotificationsModel.ItemModelExtender.count
											property string label: qsTr("Important Notifications")
										}
										QtObject {
											id: inProgressNormalPriorityNotifications
											property string icon: "Refresh"
											property string color: "steelBlue"
											property int count: inProgressNormalPriorityNotificationsModel.ItemModelExtender.count
											property string label: qsTr("Operations In Progress")
										}
									}

									model: [highPriorityNotifications, normalPriorityNotifications, inProgressNormalPriorityNotifications]

									delegate: StyledBorderRectangle {
										anchors.verticalCenter: parent.verticalCenter
										height: 18
										width: visible ? typeIndicator.width + countIndicator.width + 10 : 0
										visible: notifications.count > 0
										radius: 2

										property QtObject notifications: modelData

										Rectangle {
											id: typeIndicator
											color: notifications.color
											height: parent.height
											width: icon.width + 10

											StyledIcon {
												id: icon
												anchors.centerIn: parent
												icon: notifications.icon
												color: "#f1f1f1"
												font.pixelSize: 13
											}
										}

										StyledText {
											id: countIndicator
											anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 5 }
											color: "#666"
											text: notifications.count
										}

										OmniQml.ToolTipArea { text: notifications.label }
									}
								}
							}

						StyledBorderRectangle {
								id: newNotificationIndicator
								width: parent.width
								anchors { top: parent.top; bottom: parent.bottom }
								visible: false
								color: "#f1f1f1"

								property QtObject presentedNotification: null
								ObjectContainer { id: newNotifications }

								Item {
									id: newNotificationContents
									height: parent.height
									width: parent.width

									StyledIcon {
										id: newNotificationIcon
										anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
										icon: newNotificationIndicator.presentedNotification && newNotificationIndicator.presentedNotification.icon || "Ok"
										color: newNotificationIndicator.presentedNotification && newNotificationIndicator.presentedNotification.iconColor || "black"
									}

									StyledText {
										anchors { left: newNotificationIcon.right; right: parent.right; margins: 10; verticalCenter: parent.verticalCenter }
										text: {
											if (!newNotificationIndicator.presentedNotification) return "";
											var parts = [];
											if (newNotificationIndicator.presentedNotification.title) parts.push(newNotificationIndicator.presentedNotification.title);
											if (newNotificationIndicator.presentedNotification.text) parts.push(newNotificationIndicator.presentedNotification.text);
											return parts.join(" - ");
										}
										elide: Text.ElideRight
									}
								}

								ItemModelExtender {
									id: activeNotificationsExtender
									model: ObjectSortFilterProxyModel {
										sourceModel: globalNotificationManager.notificationsModel
										filter: ObjectBoolPropertyFilter { property: "active" }
									}
									onObjectAdded: { newNotifications.append(object); startNextNotification.start() }
									onObjectRemoved: if (object !== newNotificationIndicator.presentedNotification) newNotifications.remove(object)
								}

								Timer {
									id: startNextNotification
									interval: 1
									onTriggered: if (!newNotificationAnimation.running && !newNotifications.isEmpty()) newNotificationAnimation.start()
								}

								SequentialAnimation {
									id: newNotificationAnimation
									alwaysRunToEnd: true
									ScriptAction { script: newNotificationIndicator.presentedNotification = newNotifications.at(0) }
									PropertyAction { target: newNotificationIndicator; property: "visible"; value: true }
									ParallelAnimation {
										NumberAnimation { target: newNotificationContents; property: "opacity"; from: 0; to: 1; duration: 500 }
										NumberAnimation { target: newNotificationContents; property: "x"; from: 50; to: 0; duration: 500; }
									}
									PauseAnimation { duration: 4000 }
									NumberAnimation { target: newNotificationContents; property: "opacity"; from: 1; to: 0; duration: 500 }
									PropertyAction { target: newNotificationIndicator; property: "visible"; value: false }
									ScriptAction { script: newNotificationIndicator.presentedNotification = null }
									ScriptAction { script: { newNotifications.removeAt(0); startNextNotification.start() } }
								}
							}
					}
					//notificationZone

					Row {
						id: rightBottomRowContent
						anchors { top: parent.top; bottom: parent.bottom; }

						StyledBorderRectangle {
							id: evidenceBoxbuttonContainer

							anchors { top: parent.top; bottom: parent.bottom; }
							width: evidenceBoxContainer.visible ? evidenceBoxContainer.width : evidenceBoxButton.width
							visible: globalEvidenceBox.showEvidenceBox

							Rectangle {
									anchors { left: parent.left; top: parent.top; right: parent.right }
									height: 2
									color: StyledPalette.highlight
									visible: evidenceBoxContainer.visible
								}

							StyledTextButton {
									id: evidenceBoxButton
									text: globalEvidenceBox.evidenceBlock && globalEvidenceBox.evidenceBlock.count ? qsTr("Evidence Box (%1)").arg(globalEvidenceBox.evidenceBlock.count) : qsTr("Evidence Box")
									anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
									padding: 10
									onClicked: evidenceBoxContainer.visible = !evidenceBoxContainer.visible
								}

							StyledPopoutContainer {
									id: evidenceBoxContainer
									visible: false
									onCloseRequested: visible = false
									title: evidenceBoxButton.text
									width: 400
									height: 300
									resizePolicy { left: true; top: true; minimumWidth: 100; maximumWidth: 500; minimumHeight: 100; maximumHeight: mainPerspectiveContainer.height * 0.8 }
									anchors { left: parent.left; bottom: parent.top }
									contentClipped: false
									popoutButtonVisible: false

									Evidences.EvidenceBox {
										id: globalEvidenceBox
										anchors.fill: parent
										context: !!globalPerspectiveManager.currentPerspective &&
												 globalPerspectiveManager.currentPerspective.context || null
										alarm: !!context &&
											   !!context.alarmId &&
											   !TypeHelper.isNullUuid(context.alarmId) &&
											   !!context.alarmController &&
											   context.alarmController.alarm || null
										packagesManager: packagesManager
										onEvidenceAdded: {
											evidenceBoxContainer.visible = true
										}
									}
								}
						}

						StyledBorderRectangle {
								id: timelineButtonContainer

								anchors { top: parent.top; bottom: parent.bottom }
								width: timelineButton.width
								color: globalTimeline.visible ? "#fcfafb" : "#f1f1f1"

								Rectangle {
									anchors { left: parent.left; top: parent.top; right: parent.right }
									height: 2
									color: StyledPalette.highlight
									visible: globalTimeline.visible
								}

								StyledTextButton {
									id: timelineButton
									icon: "Time"; text: qsTr("Timeline"); padding: 10
									anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
									onClicked: { globalTimeline.visible = !globalTimeline.visible }
								}

							}

					}
					// rightBottomRowContent
				}
					// rightBottomRow
				}
				// bottomBarContainer

				Ict.IctDeviceActionUpdater {
					id: globalIctDeviceActionUpdater
					InterfaceBinding on service { value: _private.localServices.ictService }
				}
			}

			Rectangle {
				id: windowRepaintDriverItem

				color: "#f1f1f1"
				width: 1; height: 1
				opacity: 0.001

				// This item automatically forces a main window repaint rate synchronized with the Qml Animation system.
				// Thus, it avoids having additional repaints if we had the 3d engine force repaints in addition to those
				// synced with the Qml Animation system.
				NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
			}
		}

		// Defines the two states for the application:
		//			  initializing and initialized.
		// ------------------------------------------------------
		state: "initializing"
		states: [
			State {
				name: "initializing"
				PropertyChanges {
					target: initializationUi
					y: -1
				}
				PropertyChanges {
					target: mainContainer
					opacity: 0			  // Hide main container during initialization.
				}
				PropertyChanges {
					target: leftPanesContainer
					anchors.leftMargin: -width
				}
				PropertyChanges {
					target: bottomBarContainer
					anchors.bottomMargin: -height
					visible: false
				}
				PropertyChanges {
					target: timelineContainer
					opacity: 0
				}
			},

			State {
				name: "initialized"
				when: initializationUi.sequence.state === "completed"
			}
		]
		// --------------------------------------------------------


		transitions: Transition {
			ParallelAnimation {
				NumberAnimation {
					target: initializationUi
					properties: "y"
					duration: 400
					easing.type: Easing.InOutQuad
				}

				SequentialAnimation {
					PauseAnimation { duration: 150 }

					NumberAnimation {
						targets: [leftPanesContainer, bottomBarContainer]
						properties: "anchors.leftMargin,anchors.bottomMargin,opacity"
						duration: 400
						easing.type: Easing.InOutQuad
					}

					NumberAnimation {
						targets: [mainContainer, timelineContainer]
						properties: "opacity"
						duration: 400
						easing.type: Easing.InOutQuad
					}
				}
			}
		}

		FileStorage.DiskFileStorage {
			id: globalLocalFileStorage;
			rootPath: Utilities.cacheLocationPath() + "/default" // Updated during initializationSequence
		}

		OmniWorld.FileStreamCallbackConfiguration {
			callbackProvider: OmniWorld.StreamToFileStorageAdapter {
				workspacePath: globalLocalFileStorage.rootPath
				fileStorage: MetaObject.interfaceCast(globalLocalFileStorage, "GUI::USEcurity::file_storage::IFileStorage")
			}
		}

		OmniWorld.WorldObjectFactory { id: globalWorldObjectFactory; }

		ArgumentParser { id: argumentParser }

		OmniUI.SoundPlayer { id: globalSoundPlayer }

		Repeater {
			id: machineServiceFetcher

			property variant serviceReferences: _private.localServices.serviceFinder.sequenceNumber && _private.localServices.serviceFinder.findAllServiceReferencesDataByType("GUI.USEcurity.deployment.MachineService") || []
			property variant serverVersions: ({})
			onServiceReferencesChanged: {
				serverVersions = {};
				machineModelContainer.objectList = serviceReferences;
			}

			model: ObjectContainerModel { objectContainer: ObjectContainer { id: machineModelContainer } }

			Item {
				property QtObject machineService: Deployment.MachineServiceRemote {
					dispatcher: _private.localServices.rpcClient.iRpcDispatcher
					serviceReferenceData: modelData
				}
				Component.onCompleted: if (machineService && machineService.serviceReferenceData) machineWatcher.watch(machineService.getServerVersion())
				Protocall.AsyncWatcher {
					id: machineWatcher
					onCompleted: {
						if (resultData) {
							var versions = machineServiceFetcher.serverVersions;
							versions[resultData.version] = (versions[resultData.version] ? versions[resultData.version] + 1 : 1);
							machineServiceFetcher.serverVersions = versions;
						}
					}
					onFailed: {
						var versions = machineServiceFetcher.serverVersions;
						var failStr = qsTr("Unable to retrieve information");
						versions[failStr] = (versions[failStr] ? versions[failStr] + 1 : 1);
						machineServiceFetcher.serverVersions = versions;
					}
				}
			}
		}
		//  machineServiceFetcher

		Selection.SelectionController {
			id: globalSelectionController

			property QtObject menuGenerator
			menuGenerator: ContextMenuGenerator {
				Binding {
					target: globalSelectionController.menuGenerator
					property: "context"
					value: currentPerspective && currentPerspective.context || null
					when: globalApplicationWindow.active
				}

				packagesManager: packagesManager
			}

			selectionFactory: Selection.SelectionFactory {
				id: globalSelectionFactory

				Selection.MultipleSelectionBuilder { selectionFactory: globalSelectionFactory }
				AlarmsUi.AlarmSelectionBuilder { InterfaceBinding on alarmPublisher { value: _private.localServices.alarmPublisher } }
				EventsUi.EventSelectionBuilder {}
				Selection.CompositeSelectionBuilder {
					selectionBuilders: globalSelectionFactory.packageBuilders
				}
				OmniWorld.DoorSelectionBuilder {}
				OmniWorld.PlacemarkSelectionBuilder {}
				OmniWorld.FloorAndPointSelectionBuilder {}
				OmniWorld.FloorSelectionBuilder {}
				OmniWorld.MapAndPointSelectionBuilder {}
				OmniWorld.MapSelectionBuilder {}
				OmniWorld.EventSourceSelectionBuilder {}

				property variant packageBuilders: packagesManager.ready && packagesManager.getContent("selectionBuilder") || []
			}

			function showContextMenu() {
				activeSelection = selection; // Commit any deferred selectionChanged right now.
				menuGenerator.showContextMenu(activeSelection)
			}

			// As "selectionChanged" signals can be deferred, we track the currently active selection object in activeSelection, so we
			// can commit any deferred change whenever we need it.
			onSelectionChanged: activeSelection = selection
			property QtObject activeSelection
			onActiveSelectionChanged: menuGenerator.closeMenu()
		}


		Federation.SiteRegistryCache {
			id: globalSiteRegistryCache
			InterfaceBinding on siteRegistry { value: _private.localServices.siteRegistry }
			InterfaceBinding on heartBeatNotifier { value: _private.localServices.heartBeatNotifier }
		}

		Alarms.AlarmPriorityDataStoreCache {
			id: globalAlarmPriorityDataStoreCache
			ignoreDraft: true
			InterfaceBinding on datastore { value: _private.localServices.genericObjectDatastore }
		}

		//
		// Scopes
		//

		ScopePublish { key: "siteRegistryCache"; value: globalSiteRegistryCache }
		ScopePublish { key: "activeConfiguration"; value: globalActiveConfiguration }
		ScopePublish { key: "eventTypeHierarchy"; value: globalEventTypeHierarchy }
		ScopePublish { key: "searchPanelStateGroup"; value: searchPanelStateGroup }
		ScopePublish { key: "selectionController"; value: globalSelectionController }
		ScopePublish { key: "permissionsManager"; value: globalPermissionsManager }
		ScopePublish { key: "operationsManager"; value: globalOperationsManager }
		ScopePublish { key: "userRegistryCache"; value: globalUserRegistryCache }
		ScopePublish { key: "world"; value: world }
		ScopePublish { key: "readOnly"; value: !globalPerspectiveManager.currentPerspective || !globalPerspectiveManager.currentPerspective.context || globalPerspectiveManager.currentPerspective.context.readOnly; }

		Deployment.WorkstationConfigurationListCache {
			id: globalConfigurationCache

			property variant fixedConfigurationBucketId: TypeHelper.stringToUuid("51e65fb3-f6b7-45fc-aa33-93479e41df8a")
			property variant activeConfigurationKeeper: activeConfiguration && activeConfiguration.toSharedPointer() || null
			property QtObject activeConfiguration: null

			bucket: "configuration_list"
			ignoreDraft: true

			InterfaceBinding on datastore { value: _private.localServices.genericObjectDatastore }

			onUpdatingChanged: if (!updating) activeConfiguration = findById(fixedConfigurationBucketId)
		}

		XvrService.DeviceRegistrar2Aggregator {
			id: globalDeviceAggregator

			// Local properties
			property variant localRegistrarServiceReferences: localExposedServiceRegistryCache.sequenceNumber && localExposedServiceRegistryCache.findAllServiceReferencesDataByType("GUI.USEcurity.xvr_service.DeviceRegistrar2") || []
			property variant localRegistrarReferenceToRemote: ({})
			property variant localRegistrarReferenceToHealthStatus: ({})
			property variant localExporterServiceReferences: _private.localServices.serviceFinder.sequenceNumber && _private.localServices.serviceFinder.findAllServiceReferencesDataByType("GUI.USEcurity.video_clip.VideoClipExporter") || []
			property variant localExporterReferenceToRemote: ({})
			// Local signal handlers
			onLocalRegistrarServiceReferencesChanged: globalDeviceAggregator.updateRegistrars(localRegistrarServiceReferences, localExporterServiceReferences, _private.localServices.rpcClient.droppingIRpcDispatcher, true);
			onLocalExporterServiceReferencesChanged: globalDeviceAggregator.updateExporters(localExporterServiceReferences, _private.localServices.rpcClient.droppingIRpcDispatcher, true);

			// Remote properties
			property variant remoteRegistrarServiceReferences: remoteMonitoringAccessTracker.accessEnabled && _private.remoteServices.serviceFinder.sequenceNumber && _private.remoteServices.serviceFinder.findAllServiceReferencesDataByType("GUI.USEcurity.xvr_service.DeviceRegistrar2") || []
			property variant remoteRegistrarReferenceToRemote: ({})
			property variant remoteRegistrarReferenceToHealthStatus: ({})
			property variant remoteExporterServiceReferences: remoteMonitoringAccessTracker.accessEnabled && _private.remoteServices.serviceFinder.sequenceNumber && _private.remoteServices.serviceFinder.findAllServiceReferencesDataByType("GUI.USEcurity.video_clip.VideoClipExporter") || []
			property variant remoteExporterReferenceToRemote: ({})
			// Remote signal handlers
			onRemoteRegistrarServiceReferencesChanged: globalDeviceAggregator.updateRegistrars(remoteRegistrarServiceReferences, remoteExporterServiceReferences, _private.remoteServices.iRpcDispatcher, false)
			onRemoteExporterServiceReferencesChanged: globalDeviceAggregator.updateExporters(remoteExporterServiceReferences, _private.remoteServices.iRpcDispatcher, false)

			property QtObject healthStatusAggregator: HealthStatusAggregator { }

			function updateRegistrars(registrarReferences, exporterReferences, dispatcher, local) {
				if (!dispatcher) return;

				var removedReferences = [];
				var addedReferences = [];
				var refs = {};

				var registrarReferenceToRemotes = {};
				var exporterReferenceToRemotes = {};
				var referenceToHealthStatus = {};

				if (local) {
					registrarReferenceToRemotes = localRegistrarReferenceToRemote || {};
					exporterReferenceToRemotes = localExporterReferenceToRemote || {};
					referenceToHealthStatus = localRegistrarReferenceToHealthStatus || {};
				} else {
					registrarReferenceToRemotes = remoteRegistrarReferenceToRemote || {};
					exporterReferenceToRemotes = remoteExporterReferenceToRemote || {};
					referenceToHealthStatus = remoteRegistrarReferenceToHealthStatus || {};
				}

				if (!registrarReferences) {
					for (var r in registrarReferenceToRemotes) {
						removedReferences.push(r);
					}
				} else {
					for (var i = 0; i < registrarReferences.length; ++i) {
						if (!registrarReferenceToRemotes[registrarReferences[i]])
							addedReferences.push(registrarReferences[i]);

						refs[registrarReferences[i]] = true;
					}

					for (var j in registrarReferenceToRemotes) {
						if (!refs[j])
							removedReferences.push(j);
					}
				}

				// First remove all references that don't exist anymore
				for (var k = 0; k < removedReferences.length; ++k) {
					var removedReference = removedReferences[k];

					var healthStatus = referenceToHealthStatus[removedReference];
					if (healthStatus) {
						healthStatusAggregator.observables.remove(healthStatus);
						delete referenceToHealthStatus[removedReference];
						healthStatus.deleteLater();
					}

					var remote = registrarReferenceToRemotes[removedReference];
					if (remote) {
						globalDeviceAggregator.removeRegistrar(MetaObject.interfaceCast(remote, "GUI::USEcurity::xvr_service::IDeviceRegistrar2"));
						delete registrarReferenceToRemotes[removedReference];
						remote.deleteLater();
					}
				}

				// Add new registrars
				for (var m = 0; m < addedReferences.length; ++m) {
					var registrar = deviceRegistrar2Remote.createObject(globalDeviceAggregator);
					registrar.dispatcher = dispatcher;
					registrar.serviceReferenceData = addedReferences[m];
					registrarReferenceToRemotes[addedReferences[m]] = registrar;

					var capabilities = 0;
					if(registrar.serviceReferenceData
							&& registrar.serviceReferenceData.name.substring(0, 6) !== "Endura"
							&& registrar.serviceReferenceData.name.substring(0, 7) !== "Genetec"
							&& registrar.serviceReferenceData.name.substring(0, 8) !== "Intellex"
							&& registrar.serviceReferenceData.name.substring(0, 8) !== "Avigilon"
							&& registrar.serviceReferenceData.name.substring(0, 11) !== "Geutebrueck"
							&& registrar.serviceReferenceData.name.indexOf("[Archive Streaming]") === -1)
						capabilities |= XvrService.DeviceRegistrar2Aggregator.GetFrameAt;

					globalDeviceAggregator.addRegistrar(MetaObject.interfaceCast(registrar, "GUI::USEcurity::xvr_service::IDeviceRegistrar2"), capabilities);

					//Also add each registrar to the Health monitor
					var healthStatusWatchdog = deviceRegistrarHealthStatusWatchdog.createObject(globalDeviceAggregator);
					healthStatusWatchdog.objectName += getServiceReferenceDisplayName(addedReferences[m]);
					healthStatusWatchdog.remote = registrar;
					healthStatusAggregator.observables.append(healthStatusWatchdog);
					referenceToHealthStatus[addedReferences[m]] = healthStatusWatchdog;
				}

				if (local) {
					localRegistrarReferenceToRemote = registrarReferenceToRemotes;
					localExporterReferenceToRemote = exporterReferenceToRemotes;
					localRegistrarReferenceToHealthStatus = referenceToHealthStatus;
				} else {
					remoteRegistrarReferenceToRemote = registrarReferenceToRemotes;
					remoteExporterReferenceToRemote = exporterReferenceToRemotes;
					remoteRegistrarReferenceToHealthStatus = referenceToHealthStatus;
				}

				updateExporters(exporterReferences, dispatcher, local);
			}

			function updateExporters(exporterReferences, dispatcher, local) {
				if (!dispatcher) return;

				var removedReferences = [];
				var addedReferences = [];
				var refs = {};

				var exporterReferenceToRemotes = {};
				var registrarReferenceToRemotes = {};

				if (local) {
					registrarReferenceToRemotes = localRegistrarReferenceToRemote;
					exporterReferenceToRemotes = localExporterReferenceToRemote;
				} else {
					registrarReferenceToRemotes = remoteRegistrarReferenceToRemote;
					exporterReferenceToRemotes = remoteExporterReferenceToRemote;
				}

				if (!exporterReferences) {
					for (var e in exporterReferenceToRemotes) {
						removedReferences.push(e);
					}
				} else {
					for (var i = 0; i < exporterReferences.length; ++i) {
						if (!exporterReferenceToRemotes[exporterReferences[i]])
							addedReferences.push(exporterReferences[i]);

						refs[exporterReferences[i]] = true;
					}

					for (var j in exporterReferenceToRemotes) {
						if (!refs[j])
							removedReferences.push(j);
					}
				}

				// First remove all references that don't exist anymore
				for (var k = 0; k < removedReferences.length; ++k) {
					var removedReference = removedReferences[k];

					var remote = exporterReferenceToRemotes[removedReference];
					if (remote) {
						var exporterRegistrarName = getServiceReferenceDisplayName(remote.serviceReferenceData).replace(" Video Clip Exporter", " xVR");
						var exporterRegistrarName2 = "Client Side " + getServiceReferenceDisplayName(remote.serviceReferenceData).replace(" Video Clip Exporter", " Device Registrar");
						for (var registrar in registrarReferenceToRemotes) {
							if (registrar.search(exporterRegistrarName) !== -1 || registrar.search(exporterRegistrarName2) !== -1) {
								globalDeviceAggregator.removeVideoClipExporterFromRegistrar(MetaObject.interfaceCast(registrarReferenceToRemotes[registrar], "GUI::USEcurity::xvr_service::IDeviceRegistrar2"));
								delete exporterReferenceToRemotes[removedReference];
								remote.deleteLater();
							}
						}
					}
				}

				// Add new exporters
				for (var m = 0; m < addedReferences.length; ++m) {
					var exporterRegistrarName = getServiceReferenceDisplayName(addedReferences[m]).replace(" Video Clip Exporter", " xVR");
					var exporterRegistrarName2 = "Client Side " + getServiceReferenceDisplayName(addedReferences[m]).replace(" Video Clip Exporter", " Device Registrar");
					var foundRegistrar = null;
					for (registrar in registrarReferenceToRemotes) {
						if (registrar.search(exporterRegistrarName) !== -1 || registrar.search(exporterRegistrarName2) !== -1) {
							if (!foundRegistrar) {
								foundRegistrar = registrar; // if it has the same name, it has a chance to have the camera
							} else {
								var registrarData = registrarReferenceToRemotes[registrar];
								var registrarDataHasHostPort =
										registrarData && registrarData.serviceReferenceData && registrarData.serviceReferenceData.transportInfoData &&
										registrarData.serviceReferenceData.transportInfoData.host && registrarData.serviceReferenceData.transportInfoData.port;
								var exporterDataHasHostPort =
										addedReferences[m] && addedReferences[m].transportInfoData &&
										addedReferences[m].transportInfoData.host && addedReferences[m].transportInfoData.port;
								var sameHostPort = registrarDataHasHostPort && exporterDataHasHostPort &&
										(registrarData.serviceReferenceData.transportInfoData.host === addedReferences[m].transportInfoData.host) &&
										(registrarData.serviceReferenceData.transportInfoData.port === addedReferences[m].transportInfoData.port);
								if (sameHostPort) {
									foundRegistrar = registrar; // the one with the same host/port should be taken since it has better chance of having camera
								}
							}
						}
					}
					if (foundRegistrar) {
						var exporter = videoClipExporter.createObject(globalDeviceAggregator);
						exporter.dispatcher = dispatcher;
						exporter.serviceReferenceData = addedReferences[m];
						exporterReferenceToRemotes[addedReferences[m]] = exporter;
						globalDeviceAggregator.addVideoClipExporterToRegistrar(MetaObject.interfaceCast(registrarReferenceToRemotes[foundRegistrar], "GUI::USEcurity::xvr_service::IDeviceRegistrar2"), MetaObject.interfaceCast(exporter, "GUI::USEcurity::video_clip::IVideoClipExporter"));
					}
				}

				if (local) {
					localRegistrarReferenceToRemote = registrarReferenceToRemotes;
					localExporterReferenceToRemote = exporterReferenceToRemotes;
				} else {
					remoteRegistrarReferenceToRemote = registrarReferenceToRemotes;
					remoteExporterReferenceToRemote = exporterReferenceToRemotes;
				}
			}
		}

		Component {
			id: deviceRegistrarHealthStatusWatchdog
			Watchdog.RemoteWatchdog {
				name: objectName;
				objectName: qsTr("Xvr Device Registrar Service: ");
				onTestCallOpportunity: testCall(remote.getDeviceInfos())
			}
		}

		Component {
			id: deviceRegistrar2Remote
			XvrService.DeviceRegistrar2Remote { }
		}

		Component {
			id: videoClipExporter
			VideoClip.VideoClipExporterRemote { }
		}

		Item {
			id: _private

			property LocalServices localServices: LocalServices { packagesManager: packagesManager}
			property RemoteServices remoteServices: RemoteServices {
				remoteServiceRegistry: globalPermissionsManager.remoteReadPermission.allowed ? _private.localServices.remoteMonitoringServiceRegistry : null
				packagesManager: packagesManager
				ScopePublish { key: "remoteMonitoringAccessTracker"; value: remoteMonitoringAccessTracker }
			}

			Component {
				id: logOutEvent
				AuditEvents.UserLogOutUserAuditEvent {
					machineName: LocalHostName || ""
					username: globalUserRegistryCache.callingUser.samAccountName
					allowed: true

					_id: TypeHelper.createUuid();
					siteId: globalSiteRegistryCache.currentSiteData && globalSiteRegistryCache.currentSiteData._id || TypeHelper.nullUuid()
					timestamp: TypeHelper.toDateTime(new Date());
					sourceData: globalUserRegistryCache.callingUser._idData
				}
			}

			Component { id: pushEventsParametersComponent; Events.pushEventsParameters { } }

			function pushEvent(newEvent) {
				var eventsVector = TypeHelper.buildVector(newEvent.toSharedPointerCast("GUI::USEcurity::events::Event"),"GUI::USEcurity::events::Event")
				var parameters = pushEventsParametersComponent.createObject(null);
				parameters.events = eventsVector
				_private.localServices.eventSink.pushEvents(parameters.toSharedPointer())
			}
		}

		//User infor cache.
		UserRegistry.UserRegistryUserCache {
			id: globalUserRegistryCache
			InterfaceBinding on userRegistry { value: _private.localServices.userRegistry }
			property string userName: (globalUserRegistryCache.callingUser && (globalUserRegistryCache.callingUser.displayName || globalUserRegistryCache.callingUser.samAccountName)) || ""
		}

		// AD group cache
		UserRegistry.UserRegistryGroupCache {
			id: globalGroupRegistryCache
			InterfaceBinding on userRegistry { value: _private.localServices.userRegistry }
		}

		// Manages alarm creation including reports.
		//------------------------------------------------------------------
		NewUserAlarmManager {
			id: globalNewUserAlarmManager
			sopCache: _private.localServices.caches.sopDatastoreCache
			eventQueryService: _private.localServices.eventQueryDispatcherService
			callingUser: globalUserRegistryCache.callingUser
			eventSink: _private.localServices.eventSink
			alarmPerspectiveManager: globalAlarmPerspectiveManager
			alarmControl: _private.localServices.alarmControl
			alarmPriorityCache: globalAlarmPriorityDataStoreCache
			eventCache: _private.localServices.caches.eventCache
			siteId: siteTypeInfoMembers.siteId
			siteRegistryCache: globalSiteRegistryCache
			procedureOverrideCache: _private.localServices.caches.procedureOverrideCache
			procedureBlockTemplateRepository: globalProcedureBlockTemplateRepository
			packagesManager: packagesManager
			property bool ready: !!callingUser && globalUserRegistryCache.state === UserRegistry.UserRegistryUserCache.Complete
		}
		// ------------------------------------------------------------------

		Unlimited_Security.FeedController {
			id: feedController
			world: main.world
			property QtObject theFeedManager: xvrFeedManager

			feedManager: MetaObject.interfaceCast(theFeedManager, "GUI::USEcurity::xvr_service::IFeedManager")

			XvrService.XvrFeedManager {
				id: xvrFeedManager

				deviceRegistrar: MetaObject.interfaceCast(globalDeviceAggregator, "GUI::USEcurity::xvr_service::IDeviceRegistrar")
				onErrorChanged: if(error) console.log("XvrFeedManager error: "+error.message)
				InterfaceBinding on ptzMotorControl { value: _private.localServices.ptzMotorControlDispatcher }
			}
			Watchdog.GenericWatchdog {
				name: "Xvr Feed Manager"
				errorWhen: !!xvrFeedManager.error
				onTryRecover: xvrFeedManager.restartDeviceInfoQuery()
			}

			Connections {
				target: globalDeviceAggregator
				onSequenceNumberChanged: xvrFeedManager.restartDeviceInfoQuery
			}
		}

		Ptz.PtzLockManager {
			id: globalPtzLockManager
			InterfaceBinding on ptzMotorControl { value: _private.localServices.ptzMotorControlDispatcher }
		}

		TextureUploader {
			id: globalTextureUploader
			sharedContext: globalWindowGLViewport.widget
		}

		OmniUI.SpaceNavigatorDriver {
			id: globalSpaceNavigatorDriver
			dispatchToFocusedItem: false

			property QtObject _binding
			_binding: Binding {
				target: globalSpaceNavigatorDriver
				property: "targetObject"
				property QtObject spaceNavigatorFocusController: currentPerspective && currentPerspective.context && currentPerspective.context.spaceNavigatorFocusController || null
				value: spaceNavigatorFocusController && spaceNavigatorFocusController.targetObject || null
				when: globalApplicationWindow.active
			}
		}

		Unlimited_Security.AccessControlStatusManager {
			id: globalAccessControlStatusManager
			placemarksContainer: main.world ? main.world.placemarksContainer : null

			property variant localServs: _private.localServices.serviceFinder.sequenceNumber && _private.localServices.serviceFinder.findAllServiceReferencesDataByType("GUI.USEcurity.access_control.AccessControlServiceDispatcher")
			property variant remoteServs: _private.remoteServices.serviceFinder.sequenceNumber && _private.remoteServices.serviceFinder.findAllServiceReferencesDataByType("GUI.USEcurity.access_control.AccessControlServiceDispatcher")

			onLocalServsChanged: updateServices();
			onRemoteServsChanged: updateServices();

			property variant serviceToAccessControl: ({})

			function updateServices() {
				var previousAccessControlMap = serviceToAccessControl || {};
				var newAccessControlMap = { };
				var accessControls = [];

				var localServices = globalAccessControlStatusManager.localServs || [];
				var remoteServices = globalAccessControlStatusManager.remoteServs || [];

				for (var i = 0; i < localServices.length; ++i)
				{
					if (previousAccessControlMap[localServices[i]]) {
						accessControls.push(previousAccessControlMap[localServices[i]]);
						newAccessControlMap[localServices[i]] = previousAccessControlMap[localServices[i]];
					} else {
						var accessControl = accessControlRemote.createObject(globalAccessControlStatusManager);
						accessControl.dispatcher = _private.localServices.rpcClient.iRpcDispatcher;
						accessControl.serviceReferenceData = localServices[i];

						newAccessControlMap[localServices[i]] = accessControl;
						accessControls.push(accessControl);
					}
				}

				for (var j = 0; j < remoteServices.length; ++j)
				{
					if (previousAccessControlMap[remoteServices[j]]) {
						accessControls.push(previousAccessControlMap[remoteServices[j]]);
						newAccessControlMap[remoteServices[j]] = previousAccessControlMap[remoteServices[j]];
					} else {
						var accessControl = accessControlRemote.createObject(globalAccessControlStatusManager);
						accessControl.dispatcher = _private.remoteServices.iRpcDispatcher;
						accessControl.serviceReferenceData = remoteServices[j];

						newAccessControlMap[remoteServices[j]] = accessControl;
						accessControls.push(accessControl);
					}
				}

				services = accessControls;

				for (var j in previousAccessControlMap)
				{
					if (!newAccessControlMap[j])
						delete previousAccessControlMap[j];
				}

				serviceToAccessControl = newAccessControlMap;
			}

			property QtObject debug
			debug: Diagnostics.DebugSnapIn {
				name: "Door State Local Override"
				Column {
					spacing: 5
					StyledComboBox {
						objects: world && world.placemarksContainer && world.placemarksContainer.objectList.filter(function(placemark) { return MetaObject.inherits(placemark, "omniworld::Door"); }) || []
						selectedText: selection ? selection.name : qsTr("Select a Placemark");
						objectDisplayTextProperty: "name"
						onTriggered: {
							if (!selection) return;
							devicePhysStateData._id = selection.emitterUuid;
							deviceStateData._id = selection.emitterUuid;
						}
					}

					StyledComboBox {
						width: 160
						selectedText: selection ? selection : qsTr("Select a Physical State")
						property variant values: [1,2,3,4,5,6,7]
						objects: values.map(function(number) { return physicalStates.enumValueNameTr(number) } )
						onTriggered: {
							if (!selection) return;
							devicePhysState.state = values[objects.indexOf(selection)];
							globalAccessControlStatusManager.when_access_control_physical_state_changed(devicePhysStateData.clone());
						}
					}

					StyledComboBox {
						width: 160
						selectedText: selection ? selection : qsTr("Select a Control State")
						property variant values: [1,2,3,4,5]
						objects: values.map(function(number) { return controlStates.enumValueNameTr(number) } )
						onTriggered: {
							if (!selection) return;
							deviceState.state = values[objects.indexOf(selection)];
							globalAccessControlStatusManager.when_access_control_control_state_changed(deviceStateData.clone());
						}
					}

					AccessControl.PhysicalStates { id: physicalStates }
					AccessControl.ControlStates { id: controlStates }

					AccessControl.AccessDevicePhysicalStateById {
						id: devicePhysStateData
						stateData: AccessControl.AccessDevicePhysicalState { id: devicePhysState }
					}

					AccessControl.AccessDeviceControlStateById {
						id: deviceStateData
						stateData: AccessControl.AccessDeviceControlState { id: deviceState; overridden: true; }
					}
				}
			}
		}

		Component {
			id: accessControlRemote
			AccessControl.AccessControlServiceRemote { }
		}

		// We allow to launch the procedure editor from Graphics UI.
		// We need to provide for a Controller.
		ProcedureEditorController { id: globalProcedureEditorController	}

		Unlimited_Security.IctDeviceSynchronizer {
			id: globalIctDeviceSynchronizer
			placemarksContainer: main.world ? main.world.placemarksContainer : null
			deviceCache: _private.localServices.caches.ictDeviceCache
		}

		// Displays a dialog with feed permissions.
		OmniQml.Dialog {
			height: 600
			width: 800
			title: "Feed Permission Details"
			deleteOnClose: false
			visible: actionShowFeedPermissionDetails.checked
			Permissions.FeedPermissionDetailsViewer {
				id: feedPermissionViewer
				anchors.fill: parent
				visible: actionShowFeedPermissionDetails.checked
				feedPermissionProviderAggregator: globalFeedPermissionProvider
				eventSourceRegistryCache: _private.localServices.caches.eventSourceRegistryCache
				deviceRegistrarAggregator: globalDeviceAggregator
			}
		}

		ScopePublish { key: "configuration"; value: configuration }

		// Manage placemark sizing
		// -----------------------------------------------------
		Configuration {
			id: configuration

			genericObjectDatastore: _private.localServices.genericObjectDatastore
			username: globalUserRegistryCache && globalUserRegistryCache.callingUser && globalUserRegistryCache.callingUser.samAccountName || "default"

			property real placemarkIndicatorScale: clampPlacemarkIndicatorScale(configuration.value("placemark_indicator_scale", 1.0))
			onPlacemarkIndicatorScaleChanged: {
				if (isReady && (configuration.value("placemark_indicator_scale", 1.0) != placemarkIndicatorScale))
					configuration.setValue("placemark_indicator_scale", placemarkIndicatorScale);
			}

			onIsReadyChanged:  {
				var scale = configuration.value("placemark_indicator_scale", 1.0);
				if (isReady && (scale != placemarkIndicatorScale)) {
					placemarkIndicatorScale = clampPlacemarkIndicatorScale(scale);
				}
			}

			function resetPlacemarkIndicatorScale() {
				placemarkIndicatorScale = 1.0;
			}
			function increasePlacemarkIndicatorScale() {
				placemarkIndicatorScale = clampPlacemarkIndicatorScale(placemarkIndicatorScale + 0.2);
			}
			function decreasePlacemarkIndicatorScale() {
				placemarkIndicatorScale = clampPlacemarkIndicatorScale(placemarkIndicatorScale - 0.2);
			}
			function clampPlacemarkIndicatorScale(scale) {
				return Math.max(0.2, Math.min(scale, 5));
			}
		}
		// ------------------------------------------------------

		Unlimited_Security.LengthConfiguration { id: lengthConfiguration } // meters by default

		Events.LogToEventAppender {
			id: logToEventAppender
			iEventSink: MetaObject.interfaceCast(failsafeEventSinkDecorator, "GUI::USEcurity::events::IEventSink")
			userID: globalUserRegistryCache.callingUser && globalUserRegistryCache.callingUser._id || TypeHelper.getNullObject(userID)
			userName: globalUserRegistryCache.callingUser && globalUserRegistryCache.callingUser.displayName || ""
			siteID: siteTypeInfoMembers.siteId
			Component.onCompleted: logger.registerLogAppender(MetaObject.interfaceCast(logToEventAppender, "GUI::core::LogAppender"))
			Component.onDestruction: logger.unregisterLogAppender(MetaObject.interfaceCast(logToEventAppender, "GUI::core::LogAppender"))
		}

		Events.FailsafeEventSinkDecorator {
			id: failsafeEventSinkDecorator
			InterfaceBinding on target { value: _private.localServices.eventSink }
		}

		Item {
			id: siteTypeInfoMembers

			property variant siteId: globalSiteRegistryCache.currentSiteData ? globalSiteRegistryCache.currentSiteData._id : TypeHelper.nullUuid()
			property string siteName: globalSiteRegistryCache.currentSiteData ? globalSiteRegistryCache.currentSiteData.name : qsTr("(Unknown Site)")
			property int siteType: Federation.SiteTypeInfoEnum.Unknown
			property bool isCMSSite: siteType === Federation.SiteTypeInfoEnum.CMS

			Watchdog.RemoteWatchdog {
				id: siteTypeProviderWatchdog

				remote: _private.localServices.siteTypeInfoProvider
				property QtObject watcherConnection: Connections {
					target: siteTypeProviderWatchdog.testCallWatcher
					onResultChanged: {
						if (siteTypeProviderWatchdog.testCallWatcher && siteTypeProviderWatchdog.testCallWatcher.resultData)
							siteTypeInfoMembers.siteType = siteTypeProviderWatchdog.testCallWatcher.resultData.data || Federation.SiteTypeInfoEnum.Unknown
					}
				}
				onTestCallOpportunity: testCall(remote.getSiteInfo())
			}

			Diagnostics.DebugSnapIn {
				name: "Current Site"
				StyledText { text: ('name: "%1", isCMS: %2').arg(siteTypeInfoMembers.siteName).arg(siteTypeInfoMembers.isCMSSite ? "yes" : "no") }
			}
		}

		Events.EventTypeHierarchy {
			id: globalEventTypeHierarchy;

			property variant eventTypeToNameMap: typeToNameMap()
			property QtObject displayNameResolver
			displayNameResolver: Events.DefaultEventDisplayNameResolver {
				id: eventDisplayNameResolver
				eventTypeToNameMap: globalEventTypeHierarchy.eventTypeToNameMap
			}
			function eventNameFor(event) {
				return eventDisplayNameResolver.getDisplayName(event) || qsTr("Unknown Event");
			}

			property QtObject _c: Connections {
				target: packagesManager
				onReadyChanged: {
					globalEventTypeHierarchy.packagesEventTypes = packagesManager.ready && packagesManager.getContent("eventTypes", globalEventTypeHierarchy) || null
					globalEventTypeHierarchy.updatePackagesEvents();
					globalEventTypeHierarchy.eventTypeToNameMap = globalEventTypeHierarchy.typeToNameMap();
				}
			}

			property variant packagesEventTypes: []

			function updatePackagesEvents() {
				var packagesEvents = packagesEventTypes;
				for (var i = 0; i < packagesEvents.length; ++i) {
					var events = packagesEvents[i];
					for (var j = 0; j < events.length; ++j) {
						var newParent = globalEventTypeHierarchy.findNodeForType(events[j].parentType);
						if (newParent) {
							newParent.append(events[j]);
							events[j].parent = newParent;
						}
					}
				}
			}
		}

		Evidences.EvidenceBoxManager {
			id: globalEvidenceBoxManager

			sopCache: _private.localServices.caches.sopDatastoreCache
			eventCache: _private.localServices.caches.eventCache
			procedureRecordDatastore: _private.localServices.procedureRecordDatastore
			eventSourceRegistryCache: _private.localServices.caches.eventSourceRegistryCache
			alarmPerspectives: globalAlarmPerspectiveManager.localAlarmPerspectives
			currentPerspective: globalPerspectiveManager.currentPerspective
			packagesManager: packagesManager
		}

		Item {
			id: videoRendererFeature

			Process {
				id: videoRendererModule
				workingDirectory: "VideoRenderer"
				onStarted:
				{
					logger.debug("VideoRenderer executable started.");
				}
				onError:
				{
					if (videoRendererModule.running)
					{
						logger.warn("Encountered error with VideoRenderer executable, but it is still running.");
					}
					else
					{
						logger.warn("Encountered error with VideoRenderer executable, and is not running.");
					}
				}
			}

			SystemMutexWatcher { id: videoRendererMutex }

			ProtocallAuthentication.SspiTcpServerEndpoint {
				id: localExposedEndpoint

				dispatcher: Protocall.ServiceBroker {
					id: serviceBroker

					ProtocallAuthentication.HealthStatusProviderLocalDispatcher {
						objectName: "[HealthStatusProvider]"
						target: ProtocallAuthentication.DefaultHealthStatusProvider {}
					}

					Protocall.ServiceRegistryLocalDispatcher {
						id: proxyServiceRegistry
						objectName: "ProxyServiceRegistry"
						target: _private.localServices.rpcClient.iServiceRegistry
					}

					Protocall.ServiceRegistryLocalDispatcher {
						id: localExposedServiceRegistryDispatcher
						objectName: "ServiceRegistry"
						target: Protocall.ServiceRegistry { id: localExposedServiceRegistry }
					}
				}
			}

			Protocall.ServiceRegistryCache {
				id: localExposedServiceRegistryCache
				InterfaceBinding on serviceRegistry { value: localExposedServiceRegistry }
			}

			Component.onCompleted: {
				videoRendererMutex.mutexName = "VideoRenderer-Mutex-%1".arg(TypeHelper.uuidToString(TypeHelper.createUuid()));
				videoRendererMutex.acquireAndHold();

				var exposedHost = localExposedEndpoint.transportInfoData.host;
				var exposedPort = localExposedEndpoint.transportInfoData.port;

				var UI = [
					"VideoRenderer/GUI.USEcurity.VideoRenderer.exe",
					"--source_service_registry", "%1:%2/%3".arg(exposedHost).arg(exposedPort).arg(proxyServiceRegistry.objectName),
					"--target_service_registry", "%1:%2/%3".arg(exposedHost).arg(exposedPort).arg(localExposedServiceRegistryDispatcher.objectName),
					"--global_running_mutex", videoRendererMutex.mutexName
				];

				logger.debug("Exposing service registry for client side device registrar at " + exposedHost + ":" + exposedPort);

				logger.debug(videoRendererFeature, "Starting Video Renderer integration with UI '%1'".arg(UI.join(" ")));
				videoRendererModule.start(UI.join(" "));
			}
		}

		Item {
			id: diagnosticsMembers

			ObjectContainer { id: globalDebugSnapInsContainer }
		}

		Item {
			id : globalClientInfo

			property QtObject client: globalUserRegistryCache && globalUserRegistryCache.callingUser || null
			property variant clientId: client && client._idData && client._idData._id || null
			property variant groupIds: client && client.groupsData && client.groupsData.filter(function(group) { return group._idData && !TypeHelper.isNullUuid(group._idData._id) }).map(function(group) { return TypeHelper.uuidToString(group._idData._id)})

			function clientIsInGroup(groupId) {	//Guid of the group
				return groupIds.indexOf(TypeHelper.uuidToString(groupId)) >= 0;
			}
		}

		Packages.PackagesManager {
			id: packagesManager
			repository: "imports/GUI/packages"

			Deployment.LicenseFeaturesExtractor {
				id: licenseFeaturesExtractor
				licenseClientData: licenseFetcher.licenseClientData
			}

			interfaceLoader: Packages.PackageInterfaceLoader { }
		}

		Item {
			id: healthManagement

			property bool initialized: initializationUi.sequence.state === "completed"
			property bool healthy: !unhealthy
			property bool unhealthy: initialized && overallHealthAggregator.state === HealthStatus.Error
			property alias recovering: healthRecoveryTimer.running // true during a short period of time after going back to healthy.

			onUnhealthyChanged: if (!unhealthy) healthRecoveryTimer.restart()
			Timer {
				id: healthRecoveryTimer // Give some time to the user to see when things are getting back to normal
				interval: 2000
			}

			HealthStatusAggregator {
				id: overallHealthAggregator
				observables.objectList: {
					var objects = [];
					objects = objects.concat(_private.localServices.healthStatusAggregator.observables.objectList);
					if (remoteMonitoringAccessTracker.accessEnabled) objects = objects.concat(_private.remoteServices.healthStatusAggregator.observables.objectList);
					objects = objects.concat(globalDeviceAggregator.healthStatusAggregator.observables.objectList);
					objects = objects.concat(globalFeedPermissionProvider.healthStatusAggregator.observables.objectList);
					return objects;
				}
			}
			StableObjectListModel { id: healthStatusModel; objectList: overallHealthAggregator.observables.objectList }
		}

		LocalOperations {
			id: globalLocalOperations
			services: _private.localServices
			procedureBlockTemplateRepository: globalProcedureBlockTemplateRepository
		}

		Deployment.LicenseFetcher {
			id: licenseFetcher
			licenseInfoProvider: _private.localServices.licenseInfoProvider
		}

		Sops.ProcedureBlockTemplateRepository {
			id: globalProcedureBlockTemplateRepository // Name used by SopView
			paths: packagesManager.ready ? ["imports/GUI/USEcurity/sops/templates"].concat(packagesManager.loadedPackagesPath || []) : []
		}

		Item {
			id: globalOperationsManager

			function createOperation(operationComponent, properties) {
				if (!operationComponent) return null;

				var op = operationComponent.createObject(globalOperationsManager, properties || {});

				if (!op) {
					logger.error("activeOperationManager", "Could not create operation " + operationComponent.errorString());
					return null;
				}

				if (!op.progress || !op.progress.finished) {
					logger.warn("activeOperationsManager", "Provided component does not expose a progress.finished signal");
				}

				var notification = operationNotificationComponent.createObject(null, { operation: op });
				globalNotificationManager.notify(notification);

				logger.debug("activeOperationsManager", "Starting operation: %1".arg(op.displayName));
				return op;
			}

			Component {
				id: operationNotificationComponent
				Notifications.OperationNotification {
					id: operationNotification
					// This is a notification that will lose it's operation once finished.

					property string statusText: operationProgress.statusText

					Connections {
						target: operationNotification.operationProgress
						onCompleted: operationNotification.breakBindings()
						onCancelled: operationNotification.breakBindings()
					}

					function breakBindings() {
						// Break bindings and destroy the operation as to not strain the memory
						text = text;
						title = title;
						statusText = statusText;
						if (operation)
							operation.destroy();
					}

					detailsLayout: statusText.length > 0 ? statusTextComponent : null

					Component {
						id: statusTextComponent
						StyledReadOnlyTextInput {
							anchors { left: parent ? parent.left : undefined; right: parent ? parent.right : undefined }
							text: operationNotification.statusText
						}
					}
				}
			}
		}

		Item {
			id: globalNotificationManager

			property QtObject notificationsModel: ObjectContainerModel {
				propertyRoles: ["sortPriority"]
				objectContainer: globalNotificationManager.notificationContainer
			}
			property QtObject notificationContainer: ObjectContainer {}

			function notify(notification) {
				if (!notificationContainer.contains(notification)) {
					Utilities.setCppOwnership(notification);
					notificationContainer.append(notification);
					notification.sortPriorityChanged.connect(function() { notificationsModel.notifyChanged(notification) });
					notification.activeChanged.connect(function() { notificationsModel.notifyChanged(notification) });
					notification.timestampChanged.connect(function() { notificationsModel.notifyChanged(notification) });
					notification.priorityChanged.connect(function() { notificationsModel.notifyChanged(notification) });
					notification.dismissedChanged.connect(function() { notificationsModel.notifyChanged(notification) });
					notification.inProgressChanged.connect(function() { notificationsModel.notifyChanged(notification) });
				}
			}

			property QtObject permanentNotifications: ObjectContainer {}

			Timer {
				id: activeOperationsTimer
				running: true
				repeat: true
				interval: 60 * 60 * 1000 // 1 hour
				onTriggered: globalNotificationManager.cleanUp();
			}


			// Cleans notifications older than offset_ms milliseconds.
			function cleanUp() {
				var offset_ms =  24 * 60 * 60 * 1000;  // 24 hours.
				var objects = notificationContainer.objectList
				var currentTimestamp = TypeHelper.dateTimeToUnixTimestamp(TypeHelper.toDateTime(new Date()));
				var keptTimestamp = currentTimestamp - offset_ms

				objects.forEach(function(notification) {
					if (!permanentNotifications.contains(notification) && (TypeHelper.dateTimeToUnixTimestamp(notification.timestamp)) < keptTimestamp)
						Utilities.deleteObject(notification);
				})
			}

			Component {
				id: healthStatusNotificationComponent
				Notifications.Notification {
					id: healthStatusNotification

					title: qsTr("Connection Status")
					text: overallHealthAggregator.message
					sortPriority: 2

					detailsLayout: Column {
						id: servicesColumn
						spacing: 1

					function invalidateModelFilters() {
						servicesFailing.invalidateFilter();
						servicesUnavailable.invalidateFilter();
						servicesAvailable.invalidateFilter();
					}

					property bool notStartedCollapsed: true
						property bool readyCollapsed: true

						Repeater {
							model: ObjectSortFilterProxyModel {
								id: servicesFailing
								sourceModel: healthStatusModel
								filter: ObjectIntPropertyFilter {
									property: "state"
									value: HealthStatus.Warning
									operatorType: ObjectIntPropertyFilter.GreaterOrEqualThan
								}
							}
							delegate: HealthMonitor.HealthStatusElement {
								label: modelData.objectName
								healthStatus: modelData.healthStatus
								Connections { target: modelData; onStateChanged: servicesColumn.invalidateModelFilters() }
								OmniQml.ToolTipArea { text: modelData && modelData.remote && modelData.remote.serviceReferenceData? modelData.remote.serviceReferenceData.name : "" }
							}
						}

						StyledLinkButton {
							height: implicitHeight
							text: qsTr("%1 Services Not Started").arg(servicesUnavailable.count)
							onClicked: notStartedCollapsed = !notStartedCollapsed
						}

						Repeater {
							model: ObjectSortFilterProxyModel {
								id: servicesUnavailable
								sourceModel: healthStatusModel
								filter: ObjectIntPropertyFilter {
									property: "state"
									value: HealthStatus.Initializing
									operatorType: ObjectIntPropertyFilter.Equal
								}
							}
							delegate: HealthMonitor.HealthStatusElement {
								visible: !notStartedCollapsed
								label: modelData.objectName
								healthStatus: modelData.healthStatus
								Connections { target: modelData; onStateChanged: servicesColumn.invalidateModelFilters() }
								OmniQml.ToolTipArea { text: modelData && modelData.remote && modelData.remote.serviceReferenceData? modelData.remote.serviceReferenceData.name : "" }
							}
						}

						StyledLinkButton {
							height: implicitHeight
							text: qsTr("%1 Services Ready").arg(servicesAvailable.count)
							onClicked: readyCollapsed = !readyCollapsed
						}

						Repeater {
							model: ObjectSortFilterProxyModel {
								id: servicesAvailable
								sourceModel: healthStatusModel
								filter: ObjectIntPropertyFilter {
									property: "state"
									value: HealthStatus.Normal
									operatorType: ObjectIntPropertyFilter.Equal
								}
							}
							delegate: HealthMonitor.HealthStatusElement {
								visible: !readyCollapsed
								label: modelData.objectName
								healthStatus: modelData.healthStatus
								Connections { target: modelData; onStateChanged: servicesColumn.invalidateModelFilters() }
								OmniQml.ToolTipArea { text: modelData && modelData.remote && modelData.remote.serviceReferenceData? modelData.remote.serviceReferenceData.name : "" }
							}
						}
					}

					property Item _stateManager: Item {
						id: statesManager
						states: [
							State { name: "error"; when: overallHealthAggregator.state === HealthStatus.Error; PropertyChanges { target: healthStatusNotification; icon: "ExclamationSign"; iconColor: "#ee1818"; priority: healthStatusNotification.enumPriorityHigh } },
							State { name: "warning"; when: overallHealthAggregator.state === HealthStatus.Warning; PropertyChanges { target: healthStatusNotification; icon: "WarningSign"; iconColor: "#f7c14a"; priority: healthStatusNotification.enumPriorityNormal } },
							State { name: "initializing"; when: overallHealthAggregator.state === HealthStatus.Initializing; PropertyChanges { target: healthStatusNotification; icon: "Refresh"; iconColor: "#2677c2" } },
							State { name: "normal"; when: overallHealthAggregator.state === HealthStatus.Normal; PropertyChanges { target: healthStatusNotification; icon: "Circle"; text: qsTr("Ready"); iconColor: "#6ecc1b" } }
						]
						onStateChanged: {
							// Reset the notification values
							healthStatusNotification.dismissed = false;
							healthStatusNotification.timestamp = TypeHelper.toDateTime(new Date());
						}
					}
				}
			}
			Component.onCompleted: {
				var notification  = healthStatusNotificationComponent.createObject(globalNotificationManager);
				globalNotificationManager.permanentNotifications.append(notification);
				globalNotificationManager.notify(notification)
			}
		}
	}
}
