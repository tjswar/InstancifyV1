const test = require('firebase-functions-test')({
  projectId: 'instancify',
}, './service-account.json');

const admin = require('firebase-admin');
admin.initializeApp();

const myFunctions = require('../src/index');

describe('Runtime Alert Tests', () => {
  it('should create a runtime alert', async () => {
    const wrapped = test.wrap(myFunctions.scheduleRuntimeAlert);
    
    const data = {
      instanceId: 'i-test123',
      instanceName: 'Test Instance',
      region: 'us-east-1',
      hours: 1,
      minutes: 0,
      fcmToken: 'test-token',
      instanceState: 'running'
    };

    const result = await wrapped(data);
    console.log('Result:', result);
  });
}); 