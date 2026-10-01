..  include:: /Includes.rst.txt

..  _deprecation-{ISSUE}-{TIMESTAMP}:

{HEADLINE_RULE}
Deprecation: #{ISSUE} - {TITLE}
{HEADLINE_RULE}

See :issue:`{ISSUE}`

Description
===========

{What changes, in a few sentences. Use roles like :php:`TYPO3\CMS\Core\Foo` and :issue:`12345`.}


Impact
======

Calling {the deprecated API} triggers a PHP :php:`E_USER_DEPRECATED` error.
It will be removed in TYPO3 v{NEXT_MAJOR}.0.


Affected installations
======================

{Who uses it. Mention whether the extension scanner finds usages.}


Migration
=========

{Before/after with ..  code-block:: php}

..  index:: PHP-API, {FullyScanned|PartiallyScanned|NotScanned}, ext:{extension}
