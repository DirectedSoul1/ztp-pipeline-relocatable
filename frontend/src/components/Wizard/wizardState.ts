import React from 'react';

import { IpSelectorValidationType } from '../IpSelector';
import { domainValidator, ipAddressValidator } from '../utils';

import { WizardStateType } from './types';

export const useWizardState = (): WizardStateType => {
  const [mask, setMask] = React.useState('            ');
  const [maskValidation, setMaskValidation] = React.useState<IpSelectorValidationType>({
    valid: true,
    digits: [],
  });
  const handleSetMask = React.useCallback(
    (newMask: string) => {
      setMaskValidation(ipAddressValidator(newMask, true));
      setMask(newMask);
    },
    [setMask],
  );

  const [ip, setIp] = React.useState('            ');
  const [ipValidation, setIpValidation] = React.useState<IpSelectorValidationType>({
    valid: true,
    digits: [],
  });
  const handleSetIp = React.useCallback(
    (newIp: string) => {
      setIpValidation(ipAddressValidator(newIp, false));
      setIp(newIp);
    },
    [setIp],
  );

  const [domain, setDomain] = React.useState<string>('');
  const [domainValidation, setDomainValidation] =
    React.useState<WizardStateType['domainValidation']>();
  const handleSetDomain = React.useCallback((newDomain: string) => {
    setDomainValidation(domainValidator(newDomain));
    setDomain(newDomain);
  }, []);

  return {
    mask,
    maskValidation,
    handleSetMask,

    ip,
    ipValidation,
    handleSetIp,

    domain,
    domainValidation,
    handleSetDomain,
  };
};
