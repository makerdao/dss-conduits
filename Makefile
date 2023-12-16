PATH := ~/.solc-select/artifacts/solc-0.8.16:~/.solc-select/artifacts:$(PATH)
certora-conduit :; PATH=${PATH} certoraRun certora/ArrangerConduit.conf$(if $(rule), --rule $(rule),)
