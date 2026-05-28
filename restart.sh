#!/bin/bash
PROJECT=$1
supervisorctl restart "$PROJECT"
supervisorctl status "$PROJECT"