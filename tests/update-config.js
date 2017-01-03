var Promise = require('bluebird');
var auth = require('../../../test/util/auth');

var chai = require('chai');
var chaiAsPromised = require('chai-as-promised');
var assert = require('assert');

chai.use(chaiAsPromised);
expect = chai.expect;
chai.Should();

// Selectors
var FORM_PREFIX = '#csr-form ';
var SEL = {
  ISSUED_TO_SECTION: '#content > div > p:nth-child(1)',
  NEW_CERTIFICATE_LINK: '#content > a',
  COMMON_NAME_FIELD: FORM_PREFIX + 'input[type="text"][name="common_name"]',
  SUBMIT_BTN: FORM_PREFIX + ' input[type="submit"]'
};

describe('Update certificate', function() {

  var target = global.config.target;

  before(function() {
    return auth.login(browser);
  });

  it('Changes common name and verifies update', function() {
    return browser
      .url(target.getUrl('/certificate'))
      .click(SEL.NEW_CERTIFICATE_LINK)
      .setValue(SEL.COMMON_NAME_FIELD, 'foo-common-name')
      .submitForm(SEL.SUBMIT_BTN)
      .url(target.getUrl('/certificate'))
      .getText(SEL.ISSUED_TO_SECTION)
      .should.eventually.contain('foo-common-name');
  });
});
