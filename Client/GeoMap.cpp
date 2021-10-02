// Eye of the Kingdom
// Unlimited Security Application
// Purpose: GeoMap.
// ------------------------------------------------------------------

omniworld::Map2D::Map2D(omniworld::World *world)
	: omniworld::Object(world, world), _extents(new omniworld::Map2DExtents(this)), _markers(this)
{
}

omniworld::Map2D::~Map2D()
{
}

void omniworld::Map2D::setSiteId(QUuid id)
{
	if(_siteId == id) return;
	_siteId = id;
	emit siteIdChanged();
}

void omniworld::Map2D::applyRealMapId()
{
	if (!GetWorld() || !_uuid.isNull()) return;

	foreach (Floor* floor, GetWorld()->GetFloors())
	{
		if (floor->maps2DContainer()->objects().contains(this))
		{
			QString fullName = floor->GetFullPath() + "/" + name;
			QByteArray hash = QCryptographicHash::hash(fullName.toUtf8(), QCryptographicHash::Md5);
			if (hash.size() >= sizeof(QUuid))
				_uuid = *reinterpret_cast<const QUuid*>(hash.constData());

			break;
		}
	}
}

void omniworld::Map2D::setUuid(QUuid uuid)
{
	if (_uuid == uuid) return;
	_uuid = uuid;
	emit uuidChanged();
}

//
// omniworld::Map2DExtents
//

omniworld::Map2DExtents::~Map2DExtents()
{
}

bool omniworld::Map2DExtents::contains(double longitude, double latitude)
{
	return _topLeftCoordinates && _bottomRightCoordinates
			&& ((_topLeftCoordinates->latitude() >= latitude) && (_bottomRightCoordinates->latitude() <= latitude))
			&& ((_topLeftCoordinates->longitude() <= longitude) && (_bottomRightCoordinates->longitude() >= longitude));
}

void omniworld::Map2DExtents::setTopLeftCoordinates(const QSharedPointer<omniworld::GeoCoordinates> &topLeftCoordinates)
{
	if (_topLeftCoordinates && topLeftCoordinates && *_topLeftCoordinates == *topLeftCoordinates) return;
	_topLeftCoordinates = topLeftCoordinates;
	emit changed();
}

void omniworld::Map2DExtents::setBottomRightCoordinates(const QSharedPointer<omniworld::GeoCoordinates> &bottomRightCoordinates)
{
	if (_bottomRightCoordinates && bottomRightCoordinates && *_bottomRightCoordinates == *bottomRightCoordinates) return;
	_bottomRightCoordinates = bottomRightCoordinates;
	emit changed();
}

void omniworld::Map2DExtents::setTopLeftCoordinatesData(omniworld::GeoCoordinates *topLeftCoordinates)
{
	if (_topLeftCoordinates && topLeftCoordinates && *_topLeftCoordinates == *topLeftCoordinates) return;

	if (topLeftCoordinates)
		_topLeftCoordinates = omniworld::GeoCoordinates::create(topLeftCoordinates->longitude(), topLeftCoordinates->latitude(), topLeftCoordinates->altitude());
	else
		_topLeftCoordinates.clear();

	emit changed();

}

void omniworld::Map2DExtents::setBottomRightCoordinatesData(omniworld::GeoCoordinates *bottomRightCoordinates)
{
	if (_bottomRightCoordinates && bottomRightCoordinates && *_bottomRightCoordinates == *bottomRightCoordinates) return;

	if (bottomRightCoordinates)
		_bottomRightCoordinates = omniworld::GeoCoordinates::create(bottomRightCoordinates->longitude(), bottomRightCoordinates->latitude(), bottomRightCoordinates->altitude());
	else
		_bottomRightCoordinates.clear();

	emit changed();
}

void omniworld::Map2DExtents::setFrom(omniworld::Map2DExtents *extents)
{
	if (!extents) return;
	setCoordinates(extents->topLeftCoordinates(), extents->bottomRightCoordinates());
}

QString omniworld::Map2DExtents::inspect()
{
	QString coords(__FUNCTION__);
	coords.append(" topLeft ");

	if (_topLeftCoordinates)
		coords.append(QString("[lon: %1, lat: %2]").arg(_topLeftCoordinates->longitude()).arg(_topLeftCoordinates->latitude()));
	else
		coords.append("NULL");

	coords.append(" bottomRight ");
	if (_bottomRightCoordinates)
		coords.append(QString("[lon: %1, lat: %2]").arg(_bottomRightCoordinates->longitude()).arg(_bottomRightCoordinates->latitude()));
	else
		coords.append("NULL");

	return coords;
}

void omniworld::Map2DExtents::setCoordinates(const QSharedPointer<omniworld::GeoCoordinates> &topLeftCoordinates, const QSharedPointer<omniworld::GeoCoordinates> &bottomRightCoordinates)
{
	if (_topLeftCoordinates && topLeftCoordinates && *_topLeftCoordinates == *topLeftCoordinates &&
		_bottomRightCoordinates && bottomRightCoordinates && *_bottomRightCoordinates == *bottomRightCoordinates)
		return;
	_topLeftCoordinates = topLeftCoordinates;
	_bottomRightCoordinates = bottomRightCoordinates;
	emit changed();

}

//
// omniworld::Map2DPointMarker
//

omniworld::Map2DPointMarker::~Map2DPointMarker()
{
}

void omniworld::Map2DPointMarker::setLocation(const QSharedPointer<omniworld::GeoCoordinates> &location)
{
	if (_location && location && *_location == *location) return;
	_location = location;
	emit changed();
}

void omniworld::Map2DPointMarker::setLocationData(omniworld::GeoCoordinates *location)
{
	if (_location && location && *_location == *location) return;

	if (location)
		_location = omniworld::GeoCoordinates::create(location->longitude(), location->latitude(), location->altitude());
	else
		_location.clear();

	emit changed();
}

//
// omniworld::Map2DPlacemarkMarker
//

omniworld::Map2DPlacemarkMarker::Map2DPlacemarkMarker(QObject *parent)
	: omniworld::Map2DPointMarker(parent), _placemark()
{
	_orientation = HeadingTiltRollOrientation::create();
}

omniworld::Map2DPlacemarkMarker::~Map2DPlacemarkMarker()
{
}

omniworld::Placemark *omniworld::Map2DPlacemarkMarker::placemark() const
{
	return _placemark.data();
}

void omniworld::Map2DPlacemarkMarker::setPlacemark(omniworld::Placemark *placemark)
{
	if (_placemark.data() == placemark) return;
	_placemark = QWeakPointer<omniworld::Placemark>(placemark);
	emit placemarkChanged();
}

void omniworld::Map2DPlacemarkMarker::setOrientation(const QSharedPointer<omniworld::HeadingTiltRollOrientation> &orientation)
{
	if (_orientation && orientation && *_orientation == *orientation) return;
	_orientation = orientation;
	emit orientationChanged();
}

void omniworld::Map2DPlacemarkMarker::setOrientationData(omniworld::HeadingTiltRollOrientation *orientation)
{
	if (_orientation && orientation && *_orientation == *orientation) return;

	if (orientation)
		_orientation = HeadingTiltRollOrientation::create(orientation->heading(), orientation->tilt(), orientation->roll());
	else
		_orientation.clear();

	emit orientationChanged();
}
