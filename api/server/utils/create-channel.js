var util = require('util');
var fs = require('fs');
var path = require('path');
var config = require('../config.json');
var helper = require('./helper.js');
var logger = helper.getLogger('Create-Channel');

var ARTIFACTS_ROOT = path.resolve(__dirname, '../artifacts');

/**
 * Resolve channelConfigPath under server/artifacts only.
 * Accepts legacy forms like "../artifacts/channel/x.tx" or "channel/x.tx",
 * or an absolute path already inside artifacts. Rejects traversal and non-.tx files.
 */
function resolveChannelConfigPath(channelConfigPath) {
	if (typeof channelConfigPath !== 'string' || !channelConfigPath) {
		throw new Error('Invalid channelConfigPath');
	}
	var resolved;
	if (path.isAbsolute(channelConfigPath)) {
		resolved = path.resolve(channelConfigPath);
	} else {
		var relative = channelConfigPath.replace(/\\/g, '/');
		if (relative.indexOf('../artifacts/') === 0) {
			relative = relative.substring('../artifacts/'.length);
		} else if (relative.indexOf('artifacts/') === 0) {
			relative = relative.substring('artifacts/'.length);
		}
		if (path.isAbsolute(relative) || relative.split('/').indexOf('..') !== -1) {
			throw new Error('Invalid channelConfigPath');
		}
		resolved = path.resolve(ARTIFACTS_ROOT, relative);
	}
	var fromRoot = path.relative(ARTIFACTS_ROOT, resolved);
	if (!fromRoot || fromRoot === '..' || fromRoot.indexOf('..' + path.sep) === 0 || path.isAbsolute(fromRoot)) {
		throw new Error('Invalid channelConfigPath');
	}
	if (path.extname(resolved) !== '.tx') {
		throw new Error('Invalid channelConfigPath');
	}
	return resolved;
}

//Attempt to send a request to the orderer with the sendCreateChain method
var createChannel = function(channelName, channelConfigPath, username, orgName) {
	logger.debug('\n====== Creating Channel \'' + channelName + '\' ======\n');
	var client = helper.getClientForOrg(orgName);
	var channel = helper.getChannelForOrg(orgName + ':' + channelName);

	// read in the envelope for the channel config raw bytes (path constrained to artifacts/)
	var envelope = fs.readFileSync(resolveChannelConfigPath(channelConfigPath));
	// extract the channel config bytes from the envelope to be signed
	var channelConfig = client.extractChannelConfig(envelope);

	//Acting as a client in the given organization provided with "orgName" param
	return helper.getOrgAdmin(orgName).then((admin) => {
		logger.debug(util.format('Successfully acquired admin user for the organization "%s"', orgName));
		// sign the channel config bytes as "endorsement", this is required by
		// the orderer's channel creation policy
		let signature = client.signChannelConfig(channelConfig);

		let request = {
			config: channelConfig,
			signatures: [signature],
			name: channelName,
			orderer: channel.getOrderers()[0],
			txId: client.newTransactionID()
		};

		// send to orderer
		return client.createChannel(request);
	}, (err) => {
		logger.error('Failed to enroll user \''+username+'\'. Error: ' + err);
		throw new Error('Failed to enroll user \''+username+'\'' + err);
	}).then((response) => {
		logger.debug(' response ::%j', response);
		if (response && response.status === 'SUCCESS') {
			logger.debug('Successfully created the channel.');
			let response = {
				success: true,
				message: 'Channel \'' + channelName + '\' created Successfully'
			};
		  return response;
		} else {
			logger.error('\n!!!!!!!!! Failed to create the channel \'' + channelName +
				'\' !!!!!!!!!\n\n');
			throw new Error('Failed to create the channel \'' + channelName + '\'');
		}
	}, (err) => {
		logger.error('Failed to initialize the channel: ' + err.stack ? err.stack :
			err);
		throw new Error('Failed to initialize the channel: ' + err.stack ? err.stack : err);
	});
};

exports.createChannel = createChannel;
exports.resolveChannelConfigPath = resolveChannelConfigPath;
